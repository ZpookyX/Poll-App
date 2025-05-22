import os

import requests
from datetime import timedelta, datetime
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import ForeignKey, UniqueConstraint, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship, backref
from flask_login import (
    LoginManager, UserMixin, login_user,
    login_required, logout_user, current_user
)
from flask_cors import CORS
from google.oauth2 import id_token
from google.auth.transport import requests as grequests
from dotenv import load_dotenv

load_dotenv()

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

    # Two list that are backpopulated by the other tables
    comments: Mapped[list["Comment"]] = relationship("Comment", back_populates="author", cascade="all, delete-orphan")
    liked_comments: Mapped[list["CommentLike"]] = relationship("CommentLike", back_populates="user", cascade="all, delete-orphan")

    following: Mapped[list["Follow"]] = relationship(
        "Follow", foreign_keys="[Follow.follower_id]", back_populates="follower", cascade="all, delete-orphan")
    followers: Mapped[list["Follow"]] = relationship(
        "Follow", foreign_keys="[Follow.followed_id]", back_populates="followed", cascade="all, delete-orphan")

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

    comments: Mapped[list["Comment"]] = relationship("Comment", back_populates="poll", cascade="all, delete-orphan")
    options: Mapped[list["PollOption"]] = relationship("PollOption", back_populates="poll", cascade="all, delete-orphan")


class PollOption(db.Model):
    __tablename__ = "poll_option"
    option_id: Mapped[int] = mapped_column(primary_key=True)
    poll_id: Mapped[int] = mapped_column(ForeignKey("poll.poll_id"), nullable=False)
    option_text: Mapped[str] = mapped_column(nullable=False)
    votes: Mapped[list["Vote"]] = relationship(
        "Vote", back_populates="option", cascade="all, delete-orphan")

    poll = relationship("Poll", back_populates="options")

class Vote(db.Model):
    __tablename__ = "vote"
    vote_id: Mapped[int] = mapped_column(primary_key=True)
    poll_id: Mapped[int] = mapped_column(ForeignKey("poll.poll_id"), nullable=False)
    option_id: Mapped[int] = mapped_column(ForeignKey("poll_option.option_id"), nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)

    option = relationship("PollOption", back_populates="votes")

    __table_args__ = (UniqueConstraint('poll_id', 'user_id', name='_poll_user_uc'),)

# Comment model
class Comment(db.Model):
    __tablename__ = "comment"
    comment_id: Mapped[int] = mapped_column(primary_key=True)
    comment_text: Mapped[str] = mapped_column(nullable=False)
    author_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    like_count: Mapped[int] = mapped_column(nullable=True, default=0)

    # The comment is either on a poll or another comment. This constraint is checked below
    poll_id: Mapped[int] = mapped_column(ForeignKey("poll.poll_id"), nullable=True)
    parent_comment_id: Mapped[int] = mapped_column(ForeignKey("comment.comment_id"), nullable=True)

    author = relationship("User", back_populates="comments")
    poll = relationship("Poll", back_populates="comments")

    # Remote side below has to be defined since we have to foreign keys
    replies = relationship("Comment", backref=backref("parent", remote_side=[comment_id]), cascade="all, delete-orphan" )
    likes: Mapped[list["CommentLike"]] = relationship("CommentLike", back_populates="comment", cascade="all, delete-orphan")

    __table_args__ = (
        # enforce that it’s on exactly one of poll _or_ parent
        CheckConstraint(
            "(poll_id IS NOT NULL)  <>  (parent_comment_id IS NOT NULL)",
            name="ck_comment_on_one_object"
        ),
    )

class CommentLike(db.Model):
    __tablename__ = "comment_like"
    like_id:    Mapped[int] = mapped_column(primary_key=True)
    user_id:    Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    comment_id: Mapped[int] = mapped_column(ForeignKey("comment.comment_id"), nullable=False)

    user    = relationship("User", back_populates="liked_comments")
    comment = relationship("Comment", back_populates="likes")

    __table_args__ = (
        UniqueConstraint("user_id", "comment_id", name="uq_user_comment_like"),
    )

# Follow model
class Follow(db.Model):
    __tablename__ = "follow"
    follow_id: Mapped[int] = mapped_column(primary_key=True)
    follower_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    followed_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)

    follower = relationship("User",foreign_keys=[follower_id],back_populates="following")
    followed = relationship("User",foreign_keys=[followed_id],back_populates="followers")

    # Basically you can only follow someone ones and you can't follow yourself.
    __table_args__ = (
        UniqueConstraint("follower_id", "followed_id",name="uq_follower_followed"),
        CheckConstraint("follower_id <> followed_id",name="ck_no_self_follow"), # I SQL pga CheckConstraint
    )

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

# ---------------------- poll endpoints ----------------------
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
    return jsonify({'poll_id': new_poll.poll_id}), 201

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

@app.route('/polls/<poll_id>', methods=['GET'])
def retrieve_poll(poll_id):
    try:
        poll_id = int(poll_id)  # Convert poll_id string to integer
    except ValueError:
        return jsonify({'message': 'invalid poll id'}), 400

    poll = Poll.query.get(poll_id)
    if not poll:
        return jsonify({'message': 'poll not found'}), 404

    opts = [{'option_id': o.option_id,
             'option_text': o.option_text,
             'votes': len(o.votes)} for o in poll.options]

    return jsonify({'poll_id': poll.poll_id,
                    'question': poll.question,
                    'options': opts,
                    'timeleft': poll.timeleft.isoformat()}), 200


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

    option = PollOption.query.filter_by(option_id=data['option_id'], poll_id=poll_id).first()
    if not option:
        return jsonify({'message': 'option not found'}), 404

    if Vote.query.filter_by(poll_id=poll_id, user_id=current_user.id).first():
        return jsonify({'message': 'already voted'}), 400

    vote = Vote(poll_id=poll_id, option_id=data['option_id'], user_id=current_user.id)
    db.session.add(vote)
    db.session.commit()
    return jsonify({'message': 'vote recorded'}), 200

@app.route('/polls/<poll_id>/has_voted', methods=['GET'])
@login_required
def has_voted(poll_id):
    try:
        poll_id = int(poll_id)
    except ValueError:
        return jsonify({'message': 'invalid poll id'}), 400

    voted = Vote.query.filter_by(poll_id=poll_id, user_id=current_user.id).first()
    return jsonify({'voted': voted is not None}), 200

# ---------------------- comment endpoints ----------------------

@app.route('/polls/<int:poll_id>/comments', methods=['POST'])
@login_required
def comment_poll(poll_id):
    data = request.get_json() or {}
    text = data.get('comment_text')
    if not text:
        return jsonify({'message': 'comment_text is required'}), 400

    c = Comment(
        comment_text=text,
        author_id=current_user.id,
        poll_id=poll_id,
        parent_comment_id=None
    )
    db.session.add(c)
    db.session.commit()
    return jsonify({'comment_id': c.comment_id}), 201


@app.route('/comments/<int:parent_id>/replies', methods=['POST'])
@login_required
def reply_comment(parent_id):
    data = request.get_json() or {}
    text = data.get('comment_text')
    if not text:
        return jsonify({'message': 'comment_text is required'}), 400

    c = Comment(
        comment_text=text,
        author_id=current_user.id,
        poll_id=None,
        parent_comment_id=parent_id
    )
    db.session.add(c)
    db.session.commit()
    return jsonify({'comment_id': c.comment_id}), 201

@app.route('/polls/interacted', methods=['GET'])
@login_required
def interacted_polls():
    user_id = current_user.id

    # Polls with user votes
    voted_poll_ids = db.session.query(Vote.poll_id).filter_by(user_id=user_id).distinct()
    # Polls with user comments
    commented_poll_ids = db.session.query(Comment.poll_id).filter_by(author_id=user_id).distinct()

    poll_ids = set([row[0] for row in voted_poll_ids.union(commented_poll_ids) if row[0] is not None])
    polls = Poll.query.filter(Poll.poll_id.in_(poll_ids)).all()

    def serialize(p):
        return {
            'poll_id': p.poll_id,
            'question': p.question,
            'options': [{'option_id': o.option_id, 'option_text': o.option_text, 'votes': len(o.votes)} for o in p.options],
            'timeleft': p.timeleft.isoformat()
        }

    return jsonify([serialize(p) for p in polls])


# ---------------------- like endpoints ----------------------

@app.route('/comments/<int:cid>/like', methods=['POST'])
@login_required
def like_comment(cid):
    c = Comment.query.get(cid)
    if not c:
        return jsonify({'message': 'comment not found'}), 404

    if any(l.user_id == current_user.id for l in c.likes):
        return jsonify({'message': 'already liked'}), 400

    like = CommentLike(user_id=current_user.id, comment_id=cid)
    c.likes.append(like)
    db.session.commit()
    return jsonify({'like_count': len(c.likes)}), 200


@app.route('/comments/<int:cid>/like', methods=['DELETE'])
@login_required
def unlike_comment(cid):
    c = Comment.query.get(cid)
    if not c:
        return jsonify({'message': 'comment not found'}), 404

    existing = next((l for l in c.likes if l.user_id == current_user.id), None)
    if not existing:
        return jsonify({'message': 'not liked'}), 400

    c.likes.remove(existing)
    db.session.delete(existing)
    db.session.commit()
    return jsonify({'like_count': len(c.likes)}), 200


# ---------------------- follow endpoints ----------------------

@app.route('/users/<int:uid>/follow', methods=['POST'])
@login_required
def follow_user(uid):
    # no JSON body expected, so no get_json here
    if uid == current_user.id:
        return jsonify({'message': "can't follow yourself"}), 400

    if any(f.followed_id == uid for f in current_user.following):
        return jsonify({'message': 'already following'}), 400

    f = Follow(follower_id=current_user.id, followed_id=uid)
    current_user.following.append(f)
    db.session.commit()
    return jsonify({'followed_id': uid}), 201


@app.route('/users/<int:uid>/follow', methods=['DELETE'])
@login_required
def unfollow_user(uid):
    existing = next((f for f in current_user.following if f.followed_id == uid), None)
    if not existing:
        return jsonify({'message': 'not following'}), 400

    current_user.following.remove(existing)
    db.session.delete(existing)
    db.session.commit()
    return jsonify({'unfollowed_id': uid}), 200

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
