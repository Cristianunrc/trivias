class QuestionAnswer < ActiveRecord::Base
  self.table_name = 'question_answers'
  belongs_to :question
  belongs_to :answer
  belongs_to :trivia

  validates :question_id, uniqueness: { scope: [:answer_id, :trivia_id] }
  validate :consistent_combination
  validate :consistent_difficulty

  private

  def consistent_difficulty
    if question && trivia
      unless question.difficulty.level == trivia.difficulty.level
        errors.add(:base, "Question and trivia must have the same difficulty")
      end
    end
  end

  private

  def consistent_combination
    if question.blank? || trivia.blank?
      errors.add(:base, "Question, answer, and trivia must be present")
    end
  end
end
