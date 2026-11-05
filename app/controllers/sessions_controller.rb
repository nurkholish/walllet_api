class SessionsController < ApplicationController
  def create
    email    = params[:email].to_s.downcase.strip
    password = params[:password].to_s
    user     = User.find_by(email: email)

    unless user&.authenticate(password)
      return render json: { error: "invalid credentials" }, status: :unauthorized
    end

    session, token = Session.issue!(user: user, ip: request.remote_ip, user_agent: request.user_agent)

    render json: {
      token: token,
      user: { id: user.id, email: user.email, name: user.name },
      expires_at: session.expires_at
    }, status: :created
  end

  def destroy
    header = request.headers["Authorization"].to_s
    token  = header.start_with?("Bearer ") ? header.sub("Bearer ", "") : nil
    Session.find_active_by_token(token)&.revoke!
    head :no_content
  end
end