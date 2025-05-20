import os
import requests
from datetime import timedelta, datetime
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from flask_login import (
    LoginManager, UserMixin, login_user,
    login_required, logout_user, current_user
)
from flask_cors import CORS
from google.oauth2 import id_token
from google.auth.transport import requests as grequests
from dotenv import load_dotenv

load_dotenv()                          # Load variables from .env

CLIENT_IDS = [
    os.getenv("GOOGLE_CLIENT_ID_WEB"),
    os.getenv("GOOGLE_CLIENT_ID_IOS"),
    os.getenv("GOOGLE_CLIENT_ID_ANDROID"),
]

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY")
app.config['REMEMBER_COOKIE_DURATION'] = timedelta(days=30)

CORS(app,
     supports_credentials=True,
     origins=["http://localhost:5173"])

# set up db, uses sqlite
db_path = os.path.join(os.path.dirname(__file__), 'poll.db')
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
db = SQLAlchemy(app)

login_manager = LoginManager(app)

# ---------------------- models ----------------------
class User(db.Model, UserMixin):
    __tablename__ = "user"
    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(unique=True, nullable=False)

# A function for checking if the user is logged in as well as user info
@app.get('/whoami')
def whoami():
    if current_user.is_authenticated:
        return jsonify(id=current_user.id, username=current_user.username)
    return jsonify(id=None), 401

class Poll(db.Model):
    __tablename__ = "poll"
    poll_id: Mapped[int] = mapped_column(primary_key=True)
    question: Mapped[str] = mapped_column(nullable=False)
    creator_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    timeleft: Mapped[datetime] = mapped_column(nullable=False)
    options: Mapped[list["PollOption"]] = relationship(
        "PollOption", back_populates="poll", cascade="all, delete-orphan")

class PollOption(db.Model):
    __tablename__ = "poll_option"
    option_id: Mapped[int] = mapped_column(primary_key=True)
    poll_id: Mapped[int] = mapped_column(ForeignKey("poll.poll_id"), nullable=False)
    option_text: Mapped[str] = mapped_column(nullable=False)
    poll = relationship("Poll", back_populates="options")
    votes: Mapped[list["Vote"]] = relationship(
        "Vote", back_populates="option", cascade="all, delete-orphan")

class Vote(db.Model):
    __tablename__ = "vote"
    vote_id: Mapped[int] = mapped_column(primary_key=True)
    poll_id: Mapped[int] = mapped_column(ForeignKey("poll.poll_id"), nullable=False)
    option_id: Mapped[int] = mapped_column(ForeignKey("poll_option.option_id"), nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    __table_args__ = (UniqueConstraint('poll_id', 'user_id', name='_poll_user_uc'),)
    option = relationship("PollOption", back_populates="votes")

# ---------------------- Google login ----------------------
@app.route('/login', methods=['POST'])
def google_login():
    id_token_str   = request.json.get('id_token')
    access_token   = request.json.get('access_token')

    try:
        if id_token_str:
            info = id_token.verify_oauth2_token(id_token_str,
                                                grequests.Request())
            if info['aud'] not in CLIENT_IDS:
                raise ValueError
            email = info['email']
        elif access_token:
            r = requests.get(
                'https://www.googleapis.com/oauth2/v3/userinfo',
                headers={'Authorization': f'Bearer {access_token}'},
                timeout=3,
            )
            if r.status_code != 200:
                raise ValueError
            email = r.json()['email']
        else:
            return jsonify(error='Missing token'), 400

        user = User.query.filter_by(username=email).first()
        if not user:
            user = User(username=email)
            db.session.add(user)
            db.session.commit()

        login_user(user, remember=True)
        return jsonify(message='logged in',
                       user={'id': user.id, 'username': user.username}), 200
    except ValueError:
        return jsonify(error='Invalid token'), 400

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return jsonify({'message': 'logged out'}), 200

@login_manager.user_loader
def load_user(uid):
    return User.query.get(int(uid))

# ---------------------- poll endpoints (unchanged) ----------------------
@app.route('/polls', methods=['POST'])
@login_required
def create_poll():
    data = request.get_json()
    if not data or 'question' not in data or 'options' not in data:
        return jsonify({'message': 'question and options are required'}), 400
    if not isinstance(data['options'], list) or len(data['options']) < 2:
        return jsonify({'message': 'at least two options are required'}), 400

    new_poll = Poll(question=data['question'],
                    creator_id=current_user.id,
                    timeleft=datetime.now() + timedelta(hours=12)) # Hard coded for now
    db.session.add(new_poll)
    db.session.flush()

    for txt in data['options']:
        db.session.add(PollOption(poll_id=new_poll.poll_id, option_text=txt))

    db.session.commit()
    return jsonify({'poll_id': new_poll.poll_id}), 200

@app.route('/polls/<poll_id>', methods=['GET'])
def retrieve_poll(poll_id):
    poll = Poll.query.get(poll_id)
    if not poll:
        return jsonify({'message': 'poll not found'}), 404
    opts = [{'option_id': o.option_id,
             'option_text': o.option_text,
             'votes': len(o.votes)} for o in poll.options]
    return jsonify({'poll_id': poll.poll_id,
                    'question': poll.question,
                    'options': opts}), 200

@app.route('/polls/<poll_id>', methods=['DELETE'])
@login_required
def remove_poll(poll_id):
    poll = Poll.query.get(poll_id)
    if not poll:
        return jsonify({'message': "poll not found"}), 404
    votes = sum(len(o.votes) for o in poll.options)
    if votes >= 10:
        return jsonify({'message': "can't delete poll with 10+ votes"}), 400
    db.session.delete(poll)
    db.session.commit()
    return '', 200

@app.route('/polls/<poll_id>/vote', methods=['POST'])
@login_required
def vote_poll(poll_id):
    data = request.get_json()
    if not data or 'option_id' not in data:
        return jsonify({'message': 'option id is required'}), 400
    option = PollOption.query.filter_by(option_id=data['option_id'],
                                        poll_id=poll_id).first()
    if not option:
        return jsonify({'message': 'option not found'}), 404
        return jsonify({'message': 'option not found'}), 404
    if Vote.query.filter_by(poll_id=poll_id, user_id=current_user.id).first():
        return jsonify({'message': 'already voted'}), 400
    db.session.add(Vote(poll_id=poll_id,
                        option_id=data['option_id'],
                        user_id=current_user.id))
    db.session.commit()
    return jsonify({'message': 'vote recorded'}), 200

@app.route('/polls', methods=['GET'])
@login_required
def list_polls():
    filt = request.args.get('filter')
    sort = request.args.get('sort')
    polls = Poll.query.all()

    def voted(p):
        return any(v.user_id == current_user.id for o in p.options for v in o.votes)
    def count(p):
        return sum(len(o.votes) for o in p.options)

    if filt == 'unvoted':
        polls = [p for p in polls if not voted(p)]
    elif filt == 'own':
        polls = [p for p in polls if p.creator_id == current_user.id]

    if sort == 'votes':
        polls.sort(key=count, reverse=True)
    elif sort == 'votes_asc':
        polls.sort(key=count)
    elif sort == 'completed':
        polls.sort(key=voted, reverse=True)

    res = [{'poll_id': p.poll_id,
            'question': p.question,
            'options': [{'option_id': o.option_id,
                         'option_text': o.option_text,
                         'votes': len(o.votes)
            } for o in p.options],
            'timeleft': p.timeleft.isoformat()
    } for p in polls]
    return jsonify(res), 200

# ---------------------- errors & debug ----------------------
@app.errorhandler(405)
def not_allowed(e): return jsonify({'message': 'method not allowed'}), 405
@app.errorhandler(404)
def not_found(e):   return jsonify({'message': 'not found'}), 404
@app.errorhandler(400)
def bad_req(e):     return jsonify({'message': 'bad request'}), 400
@app.errorhandler(500)
def server_err(e):  return jsonify({'message': 'internal server error'}), 500

@app.before_request
def debug_log():
    print(f"{request.method} {request.path} | Auth: {current_user.is_authenticated}")

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5080)
