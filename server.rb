require_relative 'require_utils'
require 'sinatra/reloader' if Sinatra::Base.environment == :development

class App < Sinatra::Application
  include ServerConstants

  # General settings
  configure do
    enable :logging
    enable :sessions
    enable :cross_origin

    set :public_folder, "#{File.dirname(__FILE__)}/public"
    set :session_secret, SecureRandom.hex(64)

    logger = Logger.new($stdout)
    logger.level = Logger::DEBUG if development?
    set :logger, logger

    use LoginController
    use AnswerController
    use ResultsController
    use TriviaController
    use ClaimController
    use ErrorController
  end

  # Development settings
  configure :development do
    register Sinatra::Reloader
    after_reload do
      puts 'Reloaded...'
    end
  end

  # CORS settings
  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  options '*' do
    response.headers['Allow'] = 'GET, PUT, POST, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token'
    response.headers['Access-Control-Allow-Origin'] = '*'
    200
  end

  # Email settings
  Mail.defaults do
    delivery_method :smtp, {
      address: 'smtp.gmail.com',
      port: 587,
      user_name: ENV['EMAIL_AYDS'],
      password: ENV['PASSWORD_AYDS'],
      authentication: 'plain',
      enable_starttls_auto: true
    }
  end

  # Verify if exists session trivia
  before do
    if session[:trivia_id]
      @trivia = Trivia.find_by(id: session[:trivia_id])
    end
  end

  # method get_root
  # GET endpoint to displays the home page.
  #
  # This route is used to show the web application's home page when a user visits it.
  #
  # return [ERB] The home page template.
  get '/' do
    erb :index
  end

  # method get_protected_page
  # GET endpoint for displaying the protected page if the user is authenticated.
  #
  # This route displays the protected page if the user is authenticated. It checks
  # if there is a user ID stored in the session, retrieves the user's username,
  # and displays the protected page along with the rankings for different
  # difficulty levels.
  #
  # return [ERB] The protected page with rankings if the user is authenticated.
  # raise [Redirect] Redirects to '/login' if the user is not authenticated.
  get '/protected_page' do
    if session[:user_id]
      user_id = session[:user_id]
      @username = User.find(user_id).username

      beginner_difficulty = Difficulty.find_by(level: 'beginner')
      difficult_difficulty = Difficulty.find_by(level: 'difficult')

      beginner_ranking = Ranking.where(difficulty_id: beginner_difficulty.id).order(score: :desc).limit(10)
      difficult_ranking = Ranking.where(difficulty_id: difficult_difficulty.id).order(score: :desc).limit(10)

      erb :protected_page, locals: { beginner_ranking: beginner_ranking, difficult_ranking: difficult_ranking }
    else
      redirect '/login'
    end
  end

  # method get_question
  # GET endpoint for handling displaying a trivia question.
  #
  # param index [Integer] The index of the question to display.
  #
  # return [ERB] The question view for the specified trivia question.
  #
  # raise [Redirect] Redirects to '/results' if there are no more questions or if the trivia is complete.
  # raise [Redirect] Redirects to '/error?code=unanswered' if the user tries to access questions out of order.
  get '/question/:index' do
    index = params[:index].to_i
    fetch_question(index)
    erb :question, locals: {
      question: @question,
      trivia: @trivia,
      question_index: @question_index,
      answers: @answers,
      time_limit_seconds: @time_limit_seconds,
      help: @help
    }
  end

  # method current_user
  # Returns the current user based on the session.
  #
  # This method finds and returns the User object associated with the current session.
  # If there is no user_id in the session, it returns nil.
  #
  # return [User, nil] The User object if there is a user_id in the session, or nil if there isn't.
  def current_user
    User.find(session[:user_id]) if session[:user_id]
  end

  # method fetch_question
  # Method for fetching a trivia question or a translated trivia question.
  #
  # param index [Integer] The index of the question to fetch.
  # param translated [Boolean] A flag indicating whether to fetch a translated question.
  #
  # return [void]
  #
  # raise [Redirect] Redirects to '/trivia' if there's no active trivia session.
  # raise [Redirect] Redirects to '/results' if there are no more
  # questions or if the trivia is complete.
  # @raise [Redirect] Redirects to '/error?code=unanswered' if the user tries to access
  # questions out of order.
  def fetch_question(index)
    previous_index = index.zero? ? 0 : index - 1
    if index.zero? || session[:answered_questions].include?(previous_index)
      question = @trivia.questions[index]
      if question.nil? || index >= TIME_DIFFICULTY
        redirect '/results'
      else
        @question = question
        @answers = Answer.where(question_id: @question['id'])
        @time_limit_seconds = @trivia.difficulty.level == 'beginner' ? TIME_BEGINNER : TIME_DIFFICULTY
        @question_index = index
        @help = @trivia.difficulty.level == 'beginner' ? @question['help'] : nil
      end
    else
      redirect '/error?code=unanswered'
    end
  end

end
