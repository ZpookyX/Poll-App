import os
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from flask_login import (LoginManager,UserMixin,login_user,login_required,logout_user,current_user)
from flask_cors import CORS # Added this for synchronization
from google.oauth2 import id_token
from google.auth.transport import requests as grequests
from dotenv import load_dotenv

load_dotenv()  # Load variables from .env
CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")

app = Flask(__name__)
CORS(app, supports_credentials=True) # Initialiserar CORS

# set up db, uses sqlite
db_path = os.path.join(os.path.dirname(__file__), 'poll.db')
db_uri = f'sqlite:///{db_path}'
app.config['SQLALCHEMY_DATABASE_URI'] = db_uri

db = SQLAlchemy()
db.init_app(app)

login_manager = LoginManager()
login_manager.init_app(app)

# user model - we are probably gonna expand this one later
class User(db.Model, UserMixin):
    __tablename__ = "user"
    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(unique=True, nullable=False)

# poll model that holds a question and its options
class Poll(db.Model):
    __tablename__ = "poll"
    poll_id: Mapped[int] = mapped_column(primary_key=True)
    question: Mapped[str] = mapped_column(nullable=False)
    creator_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)

    # this links poll options to a poll; cascade means when poll is deleted, options are as well
    options: Mapped[list["PollOption"]] = relationship("PollOption", back_populates="poll", cascade="all, delete-orphan")

# poll option model where each option text belongs to a poll
class PollOption(db.Model):
    __tablename__ = "poll_option"
    option_id: Mapped[int] = mapped_column(primary_key=True)
    poll_id: Mapped[int] = mapped_column(ForeignKey("poll.poll_id"), nullable=False)
    option_text: Mapped[str] = mapped_column(nullable=False)

    # connects it to the Poll table
    poll = relationship("Poll", back_populates="options")

    # votes for this option, cascade deletes votes if option is removed
    votes: Mapped[list["Vote"]] = relationship("Vote", back_populates="option", cascade="all, delete-orphan")

# vote model that tracks a vote and prevents double voting per poll
# we will try to make this more anonymous in the future probably
class Vote(db.Model):
    __tablename__ = "vote"
    vote_id: Mapped[int] = mapped_column(primary_key=True)
    poll_id: Mapped[int] = mapped_column(ForeignKey("poll.poll_id"), nullable=False)
    option_id: Mapped[int] = mapped_column(ForeignKey("poll_option.option_id"), nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)

    # unique constraint so one user can only vote once per poll (we check it in the code as well so this might not
    # be needed, but maybe it's good as an extra safety net)
    __table_args__ = (UniqueConstraint('poll_id', 'user_id', name='_poll_user_uc'),)
    # connects it to Option table
    option = relationship("PollOption", back_populates="votes")

# Google login
@app.route('/login', methods=['POST'])
def google_login():
    token = request.json.get('id_token')
    if not token:
        return jsonify({'error': 'Missing token'}), 400
    try:
        idinfo = id_token.verify_oauth2_token(token, grequests.Request(), CLIENT_ID)
        email = idinfo['email']
        name = idinfo.get('name', email)
        sub = idinfo['sub']  # unique Google user ID

        user = User.query.filter_by(username=email).first()
        if not user:
            user = User(username=email)
            db.session.add(user)
            db.session.commit()

        login_user(user)
        return jsonify({'message': 'logged in', 'user': {'username': user.username, 'id': user.id}}), 200

    except ValueError:
        return jsonify({'error': 'Invalid ID token'}), 400

@app.route('/logout', methods=['GET'])
@login_required
def logout():
    logout_user()
    return jsonify({'message': 'logged out'}), 200

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# create a new poll; expects json with 'question' and 'options' (list)
@app.route('/polls', methods=['POST'])
@login_required
def create_poll():
    data = request.get_json()

    # check for missing data
    if not data or 'question' not in data or 'options' not in data:
        return jsonify({'message': 'question and options are required'}), 400
    if not isinstance(data['options'], list) or len(data['options']) < 2:
        return jsonify({'message': 'at least two options are required'}), 400

    new_poll = Poll(question=data['question'])
    db.session.add(new_poll)
    db.session.flush()  # flush so we can get poll_id for options

    for option_text in data['options']:
        option = PollOption(poll_id=new_poll.poll_id, option_text=option_text)
        db.session.add(option)

    db.session.commit()
    return jsonify({'poll_id': new_poll.poll_id}), 200

# get poll details - returns options and vote counts
@app.route('/polls/<poll_id>', methods=['GET'])
def retrieve_poll(poll_id):
    poll = Poll.query.get(poll_id)
    if not poll:
        return jsonify({'message': 'poll not found'}), 404
    options = []

    # loop through options, count votes
    for option in poll.options:
        vote_count = len(option.votes)
        options.append({
            'option_id': option.option_id,
            'option_text': option.option_text,
            'votes': vote_count
        })

    return jsonify({
        'poll_id': poll.poll_id,
        'question': poll.question,
        'options': options
    }), 200

# delete a poll; only logged in users can do this.
# later we probably want it to be so that only the poll author can delete the poll
@app.route('/polls/<poll_id>', methods=['DELETE'])
@login_required
def remove_poll(poll_id):
    poll = Poll.query.get(poll_id)
    if not poll:
        return jsonify({'message': "poll not found, can't be removed"}), 404

    # you can only delete a poll if it has less than 10 votes
    vote_count = sum(len(option.votes) for option in poll.options)
    if vote_count >= 10:
        return jsonify({'message': "can't delete poll with more than 10 votes"})
    db.session.delete(poll) # this will also delete options and votes thanks to the cascading
    db.session.commit()
    return '', 200

# vote on a poll option; user can vote only once per poll
@app.route('/polls/<poll_id>/vote', methods=['POST'])
@login_required
def vote_poll(poll_id):
    data = request.get_json()
    if not data or 'option_id' not in data:
        return jsonify({'message': 'option id is required to vote'}), 400
    poll = Poll.query.get(poll_id)
    if not poll:
        return jsonify({'message': 'poll not found'}), 404

    # check that option exists for this poll
    option = PollOption.query.filter_by(option_id=data['option_id'], poll_id=poll_id).first()
    if not option:
        return jsonify({'message': 'option not found in this poll'}), 404

    # check if user already voted in this poll
    existing_vote = Vote.query.filter_by(poll_id=poll_id, user_id=current_user.id).first()
    if existing_vote:
        return jsonify({'message': 'you have already voted in this poll'}), 400

    # if all is good, add a vote
    new_vote = Vote(poll_id=poll_id, option_id=data['option_id'], user_id=current_user.id)
    db.session.add(new_vote)
    db.session.commit()
    return jsonify({'message': 'vote recorded'}), 200

# TODO: Skapa en funktion som returnerar en lista av polls med olika val av sorteringar

# unified polls endpoint with filter and sort
@app.route('/polls', methods=['GET'])
@login_required
def list_polls():
    filt = request.args.get('filter')   # 'unvoted' or 'own'
    sort = request.args.get('sort')     # 'votes', 'votes_asc', 'completed'

    # load all polls
    polls = Poll.query.all()

    # helper to check if user voted in poll
    def has_voted(poll):
        for option in poll.options:
            for vote in option.votes:
                if vote.user_id == current_user.id:
                    return True
        return False

    # helper to count votes in poll
    def vote_count(poll):
        count = 0
        for option in poll.options:
            count += len(option.votes)
        return count

    # apply filter
    if filt == 'unvoted':
        polls = [p for p in polls if not has_voted(p)]
    elif filt == 'own':
        polls = [p for p in polls if p.creator_id == current_user.id]

    # apply sort
    if sort == 'votes':
        polls.sort(key=vote_count, reverse=True)
    elif sort == 'votes_asc':
        polls.sort(key=vote_count)
    elif sort == 'completed':
        polls.sort(key=lambda p: has_voted(p), reverse=True)

    # serialize result
    result = []
    for p in polls:
        opts = []
        for o in p.options:
            opts.append({
                'option_id': o.option_id,
                'option_text': o.option_text,
                'votes': len(o.votes)
            })
        result.append({
            'poll_id': p.poll_id,
            'question': p.question,
            'options': opts
        })
    return jsonify(result), 200

# error handlers, just returns json error messages
# lab assistant told us we needed these in a lab
@app.errorhandler(405)
def method_not_allowed(error):
    return jsonify({'message': 'method not allowed'}), 405

@app.errorhandler(404)
def page_not_found(error):
    return jsonify({'message': 'not found'}), 404

@app.errorhandler(400)
def bad_request(error):
    return jsonify({'message': 'bad request'}), 400

@app.errorhandler(500)
def internal_server_error(error):
    return jsonify({'message': 'internal server error'}), 500

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5080)
