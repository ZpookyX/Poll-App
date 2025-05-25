import pytest
from server import app, db, Poll, PollOption, Vote, User, Comment, CommentLike, Follow
from flask.sessions import SecureCookieSessionInterface
from datetime import datetime, timedelta, UTC

# ---------------------- Fixtures ----------------------

# Setup test app with in-memory DB for isolation between runs
@pytest.fixture()
def test_app():
    app.config.update({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
        "SECRET_KEY": "test_secret",
    })
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()

# Create test client from the app
@pytest.fixture()
def client(test_app):
    return test_app.test_client()

# Session interface override to avoid saving cookies
class SimpleSecureCookieSessionInterface(SecureCookieSessionInterface):
    def save_session(self, *args, **kwargs):
        pass

# Manually log in a user for tests by patching Flask's session
@pytest.fixture()
def login_user_fixture(client, test_app):
    with test_app.app_context():
        user = User(username="test@example.com")
        db.session.add(user)
        db.session.commit()
        user_id = user.id

    with client.session_transaction() as sess:
        sess["_user_id"] = str(user_id)
        sess["_fresh"] = True

    with test_app.app_context():
        return db.session.get(User, user_id)

# ---------------------- Tests below ----------------------

# This should return 401 when logged out
def test_whoami_logged_out(client):
    res = client.get("/whoami")
    assert res.status_code == 401

# Poll creation should require login
def test_create_poll_requires_login(client):
    res = client.post("/polls", json={"question": "Q", "options": ["A", "B"]})
    assert res.status_code == 401

# Create poll, vote, and block double-vote
def test_create_poll_and_vote(client, test_app, login_user_fixture):
    res = client.post("/polls", json={"question": "What is best?", "options": ["Red", "Blue"]})
    assert res.status_code == 201
    poll_id = res.get_json()["poll_id"]
    poll = db.session.get(Poll, poll_id)
    option_id = poll.options[0].option_id

    res = client.post(f"/polls/{poll_id}/vote", json={"option_id": option_id})
    assert res.status_code == 200

    res = client.post(f"/polls/{poll_id}/vote", json={"option_id": option_id})
    assert res.status_code == 400

# Test valid + invalid poll fetch
def test_retrieve_poll_and_errors(client, test_app, login_user_fixture):
    poll = Poll(question="Animal?", creator_id=login_user_fixture.id, timeleft=datetime.now(UTC) + timedelta(hours=12))
    db.session.add(poll)
    db.session.flush()
    db.session.add(PollOption(poll_id=poll.poll_id, option_text="Dog"))
    db.session.commit()

    res = client.get(f"/polls/{poll.poll_id}")
    assert res.status_code == 200

    res = client.get(f"/polls/{poll.poll_id + 99}")
    assert res.status_code == 404

    res = client.get("/polls/notanumber")
    assert res.status_code == 400


# Test deletion blocked with 10+ votes
def test_block_delete_voted_poll(client, test_app, login_user_fixture):
    poll = Poll(question="Too many votes", creator_id=login_user_fixture.id, timeleft=datetime.now(UTC) + timedelta(hours=1))
    db.session.add(poll)
    db.session.flush()
    option = PollOption(poll_id=poll.poll_id, option_text="Only")
    db.session.add(option)
    db.session.flush()
    for i in range(10):
        user = User(username=f"u{i}@e.com")
        db.session.add(user)
        db.session.flush()
        vote = Vote(poll_id=poll.poll_id, option_id=option.option_id, user_id=user.id)
        db.session.add(vote)
    db.session.commit()
    res = client.delete(f"/polls/{poll.poll_id}")
    assert res.status_code == 400

# Test creating and reading a comment on a poll
def test_comment_on_poll(client, test_app, login_user_fixture):
    poll = Poll(question="Comment test?", creator_id=login_user_fixture.id, timeleft=datetime.now(UTC) + timedelta(hours=1))
    db.session.add(poll)
    db.session.flush()
    db.session.add(PollOption(poll_id=poll.poll_id, option_text="Opt"))
    db.session.commit()

    res = client.post(f"/polls/{poll.poll_id}/comments", json={"comment_text": "Nice poll!"})
    assert res.status_code == 201
    cid = res.get_json()["comment_id"]
    assert cid is not None

    res = client.get(f"/polls/{poll.poll_id}/comments")
    assert res.status_code == 200
    comments = res.get_json()
    assert len(comments) == 1

# Test liking and unliking a comment, block double-like
def test_like_and_unlike_comment(client, test_app, login_user_fixture):
    poll = Poll(question="Like test", creator_id=login_user_fixture.id, timeleft=datetime.now(UTC) + timedelta(hours=1))
    db.session.add(poll)
    db.session.flush()
    db.session.add(PollOption(poll_id=poll.poll_id, option_text="Yes"))
    comment = Comment(comment_text="Like this!", author_id=login_user_fixture.id, poll_id=poll.poll_id)
    db.session.add(comment)
    db.session.commit()

    cid = comment.comment_id
    res = client.post(f"/comments/{cid}/like")
    assert res.status_code == 200

    res = client.post(f"/comments/{cid}/like")
    assert res.status_code == 400

    res = client.delete(f"/comments/{cid}/like")
    assert res.status_code == 200

# Test following and unfollowing another user
def test_follow_and_unfollow(client, test_app, login_user_fixture):
    other = User(username="target@example.com")
    db.session.add(other)
    db.session.commit()

    res = client.post(f"/users/{other.id}/follow")
    assert res.status_code == 201

    res = client.post(f"/users/{other.id}/follow")
    assert res.status_code == 400

    res = client.delete(f"/users/{other.id}/follow")
    assert res.status_code == 200

    res = client.delete(f"/users/{other.id}/follow")
    assert res.status_code == 400

# Test trying to follow yourself should fail
def test_self_follow_blocked(client, login_user_fixture):
    res = client.post(f"/users/{login_user_fixture.id}/follow")
    assert res.status_code == 400
