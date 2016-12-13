# frozen_string_literal: true
require "rubygems"
require "bundler"
require "erb"

Bundler.require(:default, ENV.fetch("RACK_ENV", "development"))

class Game
  DEFAULT_TABLE_COLUMNS = 6

  attr_reader :no_of_cards
  attr_reader :current_card_index

  def initialize(no_of_cards)
    @no_of_cards = no_of_cards
    @answers_map = {}
  end

  def not_started_yet?
    current_card_index.nil? && !result_ready?
  end

  def any_cards_left?
    remaining_card_indices.any?
  end

  def result_ready?
    remaining_card_indices.empty?
  end

  def current_card_index=(index)
    @current_card_index = index ? index.to_i : nil
  end

  def answer(card_index, number_is_present)
    @answers_map[card_index] = number_is_present
  end

  def answers
    @answers_map.map do |card_index, number_is_present|
      { index: card_index, value: number_is_present ? "1" : "0" }
    end
  end

  def answers=(answers)
    raise ArgumentError, "invalid argument type; expected Hash" unless answers.is_a?(Hash)

    @answers_map = {}

    answers.each do |card_index, value|
      answer(card_index.to_i, value == "1")
    end
  end

  def sample_next_card_index
    (remaining_card_indices - Array(current_card_index)).sample
  end

  def numbers_table
    return if current_card_index.nil?

    numbers_for_current_card.each_slice(DEFAULT_TABLE_COLUMNS).map do |row|
      if row.count == DEFAULT_TABLE_COLUMNS
        row
      else
        row + Array.new(DEFAULT_TABLE_COLUMNS - row.count) { |_| nil }
      end
    end
  end

  def first_number
    1
  end

  # The last number rounded down to the nearest 10th.
  def last_number
    actual_last_number - actual_last_number % 10
  end

  # The number the player thought of.
  def magic_number
    return if remaining_card_indices.any?

    @answers_map.inject(0) do |sum, (card_index, number_is_present)|
      number_is_present ? sum + (1 << card_index) : sum
    end
  end

  private

  def remaining_card_indices
    (0..no_of_cards - 1).to_a - @answers_map.keys
  end

  def numbers_for_current_card
    return if current_card_index.nil?

    (1..last_number).select { |n| n & (1 << current_card_index) != 0 }
  end

  def actual_last_number
    (1 << no_of_cards) - 1
  end
end

class App
  NO_OF_CARDS = 6

  def call(env)
    request = Rack::Request.new(env)
    response = Rack::Response.new

    game = Game.new(NO_OF_CARDS)
    game.answers = request.params["answers"] if request.post? && request.params["answers"]

    view = View.new
    view.root_url = request.path
    view.game = game

    if request.get?
      view.next_card_index = game.sample_next_card_index
      response.write(view.render)
    elsif request.post? && request.params["card_index"] && game.any_cards_left?
      game.current_card_index = request.params["card_index"]
      view.next_card_index = game.sample_next_card_index
      response.write(view.render)
    elsif request.post? && game.result_ready?
      response.write(view.render)
    else
      response = Rack::Response.new(["Not Found"], 404)
    end

    response.finish
  end
end

class View
  extend ERB::DefMethod
  include ERB::Util

  def_erb_method("render()", "app.rhtml")

  attr_accessor :root_url
  attr_accessor :game
  attr_accessor :next_card_index
end

app = Rack::Builder.new do
  use Rack::CommonLogger
  use Rack::ShowExceptions

  map "/" do
    use Rack::Lint
    run App.new
  end
end

run app
