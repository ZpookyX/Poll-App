import os

import requests
from datetime import timedelta, datetime, UTC
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
        return jsonify(
            id=current_user.id,
            username=current_user.username,
            followers=len(current_user.followers),
            following=len(current_user.following),
        )
    return jsonify(id=None), 401

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user_info(user_id):
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({'message': 'user not found'}), 404

    return jsonify({
        'id': user.id,
        'username': user.username,
        'followers': len(user.followers),
        'following': len(user.following),
    }), 200

class Poll(db.Model):
    __tablename__ = "poll"
    poll_id: Mapped[int] = mapped_column(primary_key=True)
    question: Mapped[str] = mapped_column(nullable=False)
    creator_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    timeleft: Mapped[datetime] = mapped_column(nullable=False)

    creator = relationship("User", backref="polls")
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
    post_time: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC), nullable=False)

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
    return db.session.get(User, int(uid))

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
    filter_type = request.args.get('filter')
    sort_type = request.args.get('sort')
    user_id_arg = request.args.get('user_id')

    try:
        target_user_id = int(user_id_arg) if user_id_arg else current_user.id
    except ValueError:
        return jsonify({'message': 'invalid user_id'}), 400

    all_polls = Poll.query.all()

    def user_has_voted(poll):
        for option in poll.options:
            for vote in option.votes:
                if vote.user_id == target_user_id:
                    return True
        return False

    def total_votes(poll):
        return sum(len(option.votes) for option in poll.options)

    if filter_type == 'unvoted':
        all_polls = [poll for poll in all_polls if not user_has_voted(poll)]
    elif filter_type == 'user':
        all_polls = [poll for poll in all_polls if poll.creator_id == target_user_id]
    elif filter_type == 'interacted':
        interacted = []
        for poll in all_polls:
            voted = any(vote.user_id == target_user_id for option in poll.options for vote in option.votes)
            commented = any(comment.author_id == target_user_id for comment in poll.comments)
            if voted or commented:
                interacted.append(poll)
        all_polls = interacted

    if sort_type == 'votes':
        all_polls.sort(key=total_votes, reverse=True)
    elif sort_type == 'votes_asc':
        all_polls.sort(key=total_votes)
    elif sort_type == 'completed':
        all_polls.sort(key=user_has_voted, reverse=True)

    response_data = []
    for poll in all_polls:
        response_data.append({
            'poll_id': poll.poll_id,
            'question': poll.question,
            'options': [
                {
                    'option_id': option.option_id,
                    'option_text': option.option_text,
                    'votes': len(option.votes)
                } for option in poll.options
            ],
            'timeleft': poll.timeleft.isoformat(),
            'creator_username': poll.creator.username
        })

    return jsonify(response_data), 200

@app.route('/polls/<poll_id>', methods=['GET'])
def retrieve_poll(poll_id):
    try:
        poll_id = int(poll_id)
    except ValueError:
        return jsonify({'message': 'invalid poll id'}), 400

    poll = db.session.get(Poll, poll_id)
    if not poll:
        return jsonify({'message': 'poll not found'}), 404

    options = [{'option_id': option.option_id,
                'option_text': option.option_text,
                'votes': len(option.votes)} for option in poll.options]

    return jsonify({
        'poll_id': poll.poll_id,
        'question': poll.question,
        'options': options,
        'timeleft': poll.timeleft.isoformat(),
        'creator_username': poll.creator.username
    }), 200


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

    comment = Comment(
        comment_text=text,
        author_id=current_user.id,
        poll_id=poll_id,
        parent_comment_id=None
    )
    db.session.add(comment)
    db.session.commit()
    return jsonify({'comment_id': comment.comment_id}), 201

@app.route('/comments/<int:parent_id>/replies', methods=['POST'])
@login_required
def reply_comment(parent_id):
    data = request.get_json() or {}
    text = data.get('comment_text')
    if not text:
        return jsonify({'message': 'comment_text is required'}), 400

    comment = Comment(
        comment_text=text,
        author_id=current_user.id,
        poll_id=None,
        parent_comment_id=parent_id
    )
    db.session.add(comment)
    db.session.commit()
    return jsonify({'comment_id': comment.comment_id}), 201

@app.route('/polls/<int:poll_id>/comments', methods=['GET'])
def retrieve_poll_comments(poll_id):
    poll = db.session.get(Poll, poll_id)
    if not poll:
        return jsonify({'message': 'poll not found'}), 404

    liked_ids = set()
    if current_user.is_authenticated:
        liked_ids = {like.comment_id for like in current_user.liked_comments}

    res = [{
        'comment_id': comment.comment_id,
        'comment_text': comment.comment_text,
        'author_id': comment.author_id,
        'author_username': comment.author.username,
        'like_count': len(comment.likes),
        'post_time': comment.post_time.isoformat(),
        'liked_by_user': comment.comment_id in liked_ids
    } for comment in poll.comments]

    return jsonify(res), 200


# ---------------------- like endpoints ----------------------

@app.route('/comments/<int:comment_id>/like', methods=['POST'])
@login_required
def like_comment(comment_id):
    comment = db.session.get(Comment, comment_id)
    if not comment:
        return jsonify({'message': 'comment not found'}), 404

    if any(like.user_id == current_user.id for like in comment.likes):
        return jsonify({'message': 'already liked'}), 400

    like = CommentLike(user_id=current_user.id, comment_id=comment_id)
    comment.likes.append(like)
    db.session.commit()
    return jsonify({'like_count': len(comment.likes)}), 200


@app.route('/comments/<int:comment_id>/like', methods=['DELETE'])
@login_required
def unlike_comment(comment_id):
    comment = db.session.get(Comment, comment_id)
    if not comment:
        return jsonify({'message': 'comment not found'}), 404

    existing = next((like for like in comment.likes if like.user_id == current_user.id), None)
    if not existing:
        return jsonify({'message': 'not liked'}), 400

    comment.likes.remove(existing)
    db.session.delete(existing)
    db.session.commit()
    return jsonify({'like_count': len(comment.likes)}), 200


# ---------------------- follow endpoints ----------------------

@app.route('/users/<int:uid>/follow', methods=['POST'])
@login_required
def follow_user(uid):
    if uid == current_user.id:
        return jsonify({'message': "can't follow yourself"}), 400

    if any(follow.followed_id == uid for follow in current_user.following):
        return jsonify({'message': 'already following'}), 400

    f = Follow(follower_id=current_user.id, followed_id=uid)
    current_user.following.append(f)
    db.session.commit()
    return jsonify({'followed_id': uid}), 201


@app.route('/users/<int:uid>/follow', methods=['DELETE'])
@login_required
def unfollow_user(uid):
    existing = next((follow for follow in current_user.following if follow.followed_id == uid), None)
    if not existing:
        return jsonify({'message': 'not following'}), 400

    current_user.following.remove(existing)
    db.session.delete(existing)
    db.session.commit()
    return jsonify({'unfollowed_id': uid}), 200

@app.route('/users/<int:user_id>/following_status', methods=['GET'])
@login_required
def check_following_status(user_id):
    if user_id == current_user.id:
        return jsonify({'message': 'cannot follow yourself'}), 400

    is_following = any(follow.followed_id == user_id for follow in current_user.following)
    return jsonify({'is_following': is_following}), 200

@app.route('/users/me/following', methods=['GET'])
@login_required
def list_my_following():
    followed_ids = [follow.followed_id for follow in current_user.following]
    return jsonify(followed_ids), 200

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
