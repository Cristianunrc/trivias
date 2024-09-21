require_relative '../server'
require_relative '../constants'

class TriviaController < Sinatra::Base
  include ServerConstants

  # @!method setup_trivia
  # Sets up a trivia game with standard or translated questions based on the parameters.
  #
  # This method orchestrates the creation of a trivia game by calling methods to initialize
  # the trivia object, setting up either standard trivia questions, and then
  # finalizing the trivia setup by saving it and setting up the session.
  #
  # @param params [Hash] The request parameters containing the difficulty level and, if applicable, the selected language code for translations.
  # @param session [Hash] The current user's session for retrieving user data and storing the trivia session.
  # @return [void]
  # @see get_user_difficulty_trivia
  # @see setup_standard_trivia
  # @see finalize_trivia_setup
  def setup_trivia(params, session)
    user, difficulty, trivia = get_user_difficulty_trivia(params, session)
    setup_standard_trivia(trivia, difficulty)
    finalize_trivia_setup(trivia, session)
  end

  # @!method get_user_difficulty_trivia
  # Retrieves the current user, the selected difficulty, and initializes a new trivia object.
  #
  # This method is responsible for finding the current user from the session, fetching the difficulty level from the request parameters,
  # and creating a new trivia instance with those parameters.
  #
  # @param params [Hash] The request parameters containing the difficulty level.
  # @param session [Hash] The current user's session for retrieving user data.
  # @return [Array] An array containing the user, the difficulty object, and the newly initialized trivia object.
  # @see User#find
  # @see Difficulty#find_by
  # @see Trivia#new
  def get_user_difficulty_trivia(params, session)
    user = User.find(session[:user_id]) if session[:user_id]
    difficulty_level = params[:difficulty]
    difficulty = Difficulty.find_by(level: difficulty_level)
    trivia = Trivia.new(user: user, difficulty: difficulty)
    [user, difficulty, trivia]
  end

  # @!method setup_standard_trivia
  # Sets up standard trivia questions for the game.
  #
  # This method adds a set number of random choice, true/false, and autocomplete questions to the trivia
  # based on the difficulty level provided.
  #
  # @param trivia [Trivia] The trivia object to which the questions will be added.
  # @param difficulty [Difficulty] The difficulty object that determines the number and type of questions to add.
  # @return [void]
  # @see get_questions_count
  # @see get_questions
  def setup_standard_trivia(trivia, difficulty)
    choice_count, true_false_count, autocomplete_count = get_questions_count(difficulty.level)
    questions = get_questions(choice_count, true_false_count, autocomplete_count, difficulty)
    trivia.questions.concat(questions)
  end

  # @!method finalize_trivia_setup
  # Finalizes the trivia setup by saving the trivia instance and initializing session variables.
  #
  # This method is called after setting up the trivia questions. It saves the trivia instance to the database
  # and initializes the session variables to track the trivia id and the questions answered by the user.
  #
  # @param trivia [Trivia] The trivia instance that needs to be finalized and saved.
  # @param session [Hash] The session hash where the trivia id and answered questions are stored.
  # @return [void]
  def finalize_trivia_setup(trivia, session)
    trivia.save
    session[:trivia_id] = trivia.id
    session[:answered_questions] = []
  end

  # @!method get_questions_count
  # Determines the count of different types of questions based on the difficulty level.
  #
  # This method calculates how many choice, true/false, and autocomplete questions should be included in the trivia
  # based on the difficulty level provided. It ensures the total count adds up to 10 questions.
  #
  # @param difficulty_level [String] The level of difficulty selected for the trivia.
  # @return [Array<Integer>] An array containing the count of choice, true/false, and autocomplete questions.
  def get_questions_count(difficulty_level)
    if difficulty_level == 'beginner'
      choice_count = rand(3..6)
      true_false_count = rand(3..4)
    else
      choice_count = rand(2..5)
      true_false_count = rand(2..4)
    end
    remaining_count = 10 - choice_count - true_false_count
    autocomplete_count = [remaining_count, 0].max
    [choice_count, true_false_count, autocomplete_count]
  end

  # @!method get_questions
  # Retrieves a shuffled array of questions for the trivia.
  #
  # This method gathers a specified number of choice, true/false, and autocomplete questions based on counts provided.
  # It then shuffles the collection of questions before returning them.
  #
  # @param choice_count [Integer] The number of choice questions to retrieve.
  # @param true_false_count [Integer] The number of true/false questions to retrieve.
  # @param autocomplete_count [Integer] The number of autocomplete questions to retrieve.
  # @param difficulty [Difficulty] The difficulty object associated with the questions.
  # @return [Array<Question>] An array of questions, shuffled and ready to be added to the trivia.
  def get_questions(choice_count, true_false_count, autocomplete_count, difficulty)
    choice_questions = random_questions(choice_count, 'Choice', difficulty)
    true_false_questions = random_questions(true_false_count, 'True_False', difficulty)
    autocomplete_questions = random_questions(autocomplete_count, 'Autocomplete', difficulty)
    questions = choice_questions.to_a + true_false_questions.to_a + autocomplete_questions.to_a
    shuffled_questions = questions.shuffle
    shuffled_questions
  end

  # @!method random_questions
  # Fetches a random set of questions from the database.
  #
  # This method selects a random assortment of questions of a particular type and difficulty from the database.
  # It is used to assemble the pool of questions for the trivia game.
  #
  # @param question_count [Integer] The number of questions to retrieve.
  # @param question_type [String] The type of questions to retrieve ('Choice', 'True_False', or 'Autocomplete').
  # @param difficulty [Difficulty] The difficulty level of the questions to retrieve.
  # @return [ActiveRecord::Relation<Question>] A collection of question records.
  def random_questions(question_count, question_type, difficulty)
    difficulty.questions
              .where(type: question_type)
              .order('RANDOM()')
              .limit(question_count)
  end

  # @!method post_trivia
  # Post endpoint that handles the initiation of a standard trivia game.
  #
  # This endpoint is responsible for setting up a new trivia game with standard questions.
  # It sets up the trivia using provided parameters and session information, and then
  # redirects the user to the first question of the trivia game.
  #
  # @param params [Hash] The parameters from the POST request, including difficulty level.
  # @param session [Hash] The session object to store trivia state.
  # @return [Redirect] A redirect to the first question of the new trivia game.
  post '/trivia' do
    setup_trivia(params, session)
    redirect '/question/0'
  end

end
