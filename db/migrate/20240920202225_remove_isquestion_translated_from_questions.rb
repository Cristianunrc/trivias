class RemoveIsquestionTranslatedFromQuestions < ActiveRecord::Migration[7.0]
  def change
    remove_column :questions, :is_question_translated
  end
end
