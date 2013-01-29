require 'chingu'
include Chingu
include Gosu

require 'helpers/measures'
require 'helpers/dices'
require 'states/combat_state'

require 'pitch/square'
require 'pitch/floating_text'
require 'pitch/pitch'

require 'player/actions'
require 'player/states'
require 'player/health'

class Player < GameObject
	include Helpers::Measures
	include Helpers::Dices

	include Actions
	include States

	traits :bounding_circle
	attr_reader :team, :cur_ma, :stats, :race, :role, :health

	@@str = 3
	@@agi = 2
	@@ma  = 4
	@@arm = 6

	def initialize options = {}
		super
		@team       = options[:team]  or raise ArgumentError, "Missing team number for #{self}"
		@pitch      = options[:pitch] or raise ArgumentError, "Unable to fetch pitch for #{self}"
		@ball       = options[:ball]  or raise ArgumentError, "Unable to find ball for #{self}"
		@race       = options[:race]  or raise ArgumentError, "You did not specifiy a race for #{self}"
		@role       = options[:role]  or raise ArgumentError, "You did not specifiy a role for #{self}"
		@image      = Image["teams/#{race}/#{role}#{@team.side}.gif"]
		@x, @y      = to_screen_coords [options[:x], options[:y]] rescue nil
		@target_x   = @x
		@target_y   = @y
		@velocity   = 0.23

		@footsteps  = Sample["footsteps.ogg"]

		@selected   = false

		@stats      = {:str => @@str + rand(2), :agi => @@agi + rand(2), :ma => @@ma + rand(2), :arm => @@arm + rand(2)}
		@abilities  = []
		@has_ball   = options[:has_ball] or false
		@health     = Health::OK
		@health_txt = FloatingText.create("", :x => @x + 5, :y => @y + 5, :timer => 0, :color => 0xFFFF0000)
		new_turn!
	end

	def setup
		self.input = { :mouse_left => :select }
	end

	def select
		if to_pitch_coords( [ $window.mouse_x, $window.mouse_y ] ) == pos
			@selected = true
		else
			@selected = false
		end
		notify_ring_change
	end

	def unselect
		@selected = false
		notify_ring_change
	end

	def new_turn!
		@can_move  = true
		@has_moved = false
		@cur_ma    = @stats[:ma]
		@cur_node  = 0
		@path      = nil
		@blitz     = false
		notify_ring_change
		# Later we will have to manage injuries recovery down there
		if (Health::STUN_1..Health::STUN_2).member? @health
			@health -= 1
			notify_health_change
		end
	end

	def end_turn
		@team.end_turn!
	end

	# -------------------------------
	# ----------- Graphic -----------
	# -------------------------------

	def draw
		if on_pitch?
			@square.draw if @square
			super
		end
	end

	def update
		super
		unless @path.nil?
			ms = $window.milliseconds_since_last_tick rescue nil

			t_pos = to_screen_coords @path[@cur_node]
			c_pos = [@x, @y]

			vx, vy = 0, 0

			vx = (t_pos[0] - c_pos[0]) / (t_pos[0] - c_pos[0]).abs * @velocity * ms unless c_pos[0] == t_pos[0]
			vy = (t_pos[1] - c_pos[1]) / (t_pos[1] - c_pos[1]).abs * @velocity * ms unless c_pos[1] == t_pos[1]

			tx, ty = 0, 0

			if (c_pos[0] - t_pos[0]).abs < 5
				tx = t_pos[0]
			else
				tx = @x + vx
			end

			if (c_pos[1] - t_pos[1]).abs < 5
				ty = t_pos[1]
			else
				ty = @y + vy
			end

			if [tx, ty] == t_pos
				success = true
				success = catch! if @ball.pos == @path[@cur_node] unless @has_ball
				if has_ball?
					x, y = @path[@cur_node]
					if (@team.side == :A and y == Pitch::WIDTH - 1) or (@team.side == :B and y == 0)
						@team.inc :score
					end
				end
				unless success
					@cur_node = @path.size
				else
					@cur_node += 1
				end
				@cur_ma   -= 1
				@footsteps.play
			end

			@x, @y = tx, ty
			@ball.set_pos! @x, @y, false if @has_ball

			if @cur_node == @path.size
				@path = nil
				@pitch.unlock
			end

			cant_move! if @cur_ma == 0 and not @blitz and not @has_ball
			notify_ring_change
			notify_health_change
		end
	end

	# -------------------------------
	# ----------- Actions -----------
	# -------------------------------

	def event! symb
		msg = ""
		color = 0xFF00FF00
		success = true
		case symb
		when :pass
			msg = "Pass !"
		when :fumble
			msg = "Fumble !"
			success = false
			color = 0xFFFF0000
		when :fail
			msg = "Fail !"
			success = false
			color = 0xFFFF0000
		when :catch
			msg = "Catch !"
		when :block
			msg = "Block !"
		when :dodge
			msg = "Dodge !"
		end
		@text.destroy! if @text # We do not want to have many text boxes displayed at the same time
		@text = FloatingText.create(msg, :x => @x, :y => @y - height - 22, :timer => 2000, :color => color)
		end_turn unless success
	end

	# -------------------------------
	# ---------- Listeners ----------
	# -------------------------------

	def notify_health_change
		@health_txt.color = case @health - 1
		when 2
			0xFFFF0000
		when 1
			0xFFE96900
		when 0
			0xFF00FF00
		else
			0xFFFFFFFF
		end
			@health_txt.x    = @x + 5
			@health_txt.y    = @y + 5
		if (Health::STUN_0..Health::STUN_2).member? @health
			@health_txt.text = "#{@health - 1}"
		else
			@health_txt.text = ""
		end
	end

	def notify_ring_change
		params = {:x => @x, :y => @y, :color => :yellow}
		if @selected
			@square = StateSquare.new params.merge(:color => :yellow)
		elsif @team.active?
			if can_move?
				@square = StateSquare.new params.merge(:color => :green)
			else
				@square = StateSquare.new params.merge(:color => :red)
			end
		else
			@square = nil
		end
	end
end
