require "chingu"
include Chingu
include Gosu

require "barrier"
require "team"
require "player"
require "config"
require "ball"

class Pitch < GameObject
	include Helpers::Measures
	include Helpers::Barrier

	attr_reader :teams, :active_team, :ball

	WIDTH       = 26
	HEIGHT      = 15
	SQUARE_W    = 49.7
	SQUARE_H    = 48.8
	SPACE_X     = 3
	SPACE_Y     = 3
	MARGIN_LEFT = 8
	MARGIN_TOP  = 5

	def initialize
		super
		@image  = Image["pitch.jpg"]
		@y      = 15
		@zorder = 1
		rotation_center(:top_left)

		@teams = []
		@teams << Team.new( :name => "TROLOLOL", :active => true, :side => :A, :pitch => self )
		@teams << Team.new( :name => "OTAILLO", :side => :B, :pitch => self )

		load
	end

	def start_new_game ball
		raise ArgumentError unless ball.is_a? Ball
		@ball = ball
		each { |p| p.set_stage :stage => :play, :ball => @ball }
		@active_team = @teams[0]
		@active_team.new_turn!
	end

	def new_turn!
		@turnover = false
		@active_team.active = false
		@active_team = @teams[(@active_team.number + 1) % 2]
		@active_team.new_turn!
	end

	def turnover!
		@turnover = true
	end

	def turnover?
		@turnover
	end

	def [] pos
		@teams.each { |t| return t[pos] unless t[pos].paused? if t[pos]}
		nil
	end

	def each &block
		@teams.each do |team|
			team.each do |player|
				yield player
			end
		end
	end

	def active_players_around pos, filter = :none
		filter = :none unless self[pos] # Filters have no sense unless there is a player at pos
		res = []
		-1.upto 1 do |i|
			-1.upto 1 do |j|
				unless i == 0 and i == 0
					x, y = pos[0] + i, pos[1] + j
					case filter
					when :allies
						res << self[[x,y]] if self[[x,y]] and self[[x,y]].health == Health::OK and self[[x,y]].team == self[pos].team
					when :opponents
						res << self[[x,y]] if self[[x,y]] and self[[x,y]].health == Health::OK and self[[x,y]].team != self[pos].team
					when :none
						res << self[[x,y]] if self[[x,y]] and self[[x,y]].health == Health::OK
					end
				end
			end
		end
		res
	end

	def each_active_players_around pos, &block
		active_players_around(pos).each { |p| yield p }
	end

	def active_team= team
		@teams.each { |t| t.active = false }
		@active_team = team
		@active_team.new_turn!
	end

	def unlock
		super
		@unlock_listener.call if @unlock_listener
	end

	def on_unlock &block
		@unlock_listener = block
	end

	# Since we do not load it statically anymore, this seems to take much more time.
	# We shall watch by there if we can improve this
	def load
		Configuration.instance[:teams].each do |team|
			race = team[:race]
			num  = team[:num]
			team[:players].each do |player|
				role = player[:role]
				pos  = player[:pos]
				x, y = pos
				@teams[num] << Player.create(
					:team => @teams[num],
					:x => x,
					:y => y,
					:pitch => self,
					:race => race,
					:role => role
				)
			end
		end
	end
end