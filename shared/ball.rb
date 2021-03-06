require 'chingu'
include Chingu
include Gosu
require 'singleton'

require 'measures'

class Ball < GameObject
	include Helpers::Measures

	def initialize options = {}
		x, y = 0, 0
		x, y = to_screen_coords [options.delete(:x), options.delete(:y)] if options[:x] and options[:y]
		super :x => x, :y => y, :image => Image["ball.png"], :zorder => 101
		@pitch    = options[:pitch] or raise "Unable to fetch pitch for #{self}"
		@velocity = 0.4

		@target_x, @target_y = x, y
		@last_x, @last_y = pos
	end

	##
	# Takes pitch coordinates
	# TODO : we gotta handle the case when the ball leaves the pitch
	def move_to! x, y
		coords = [x, y]
		return nil if coords.nil?
		unless coords == pos
			@pitch.lock
			dist = dist pos, coords
			@dx  = (x - @x) / dist
			@dy  = (y - @y) / dist
			x, y = to_screen_coords [x, y]
			set_pos! x, y, true
		end
	end

	def handoff_to! x, y
		@handoff = true
		move_to! x, y
	end

	def handoff?
		@handoff
	end

	def handoff= value
		raise("Argument should be a boolean") unless value == true or value == false
		@handoff = value
	end

	##
	# Takes pitch coordinates
	def move_by! x, y
		move_to! @x + y, @y + y
	end

	##
	# Takes screen coordinates
	def set_pos! x, y, animate=false
		@target_x = x
		@target_y = y
		unless animate
			@x = x
			@y = y
		end
	end

	def screen_pos
		[@x, @y]
	end

	def pos
		to_pitch_coords screen_pos
	end

	def scatter! dist=1, coords=pos
		return nil if coords.nil? or dist == 0
		t_x, t_y = coords
		x, y = 0, 0
		dist.times do
			while [x, y] == [0, 0]
				x = [-1, 0, 1].sample
				y = [-1, 0, 1].sample
			end
			t_x += x
			t_y += y
		end
		move_to! t_x, t_y
	end

	def scatter_from_last_pos!
		t_x, t_y = to_pitch_coords [@last_x, @last_y]
		x, y = 0, 0
		while [x, y] == [0, 0] and not @pitch.collision_at?(to_screen_coords([@last_x, @last_y]))
			x = [-1, 0, 1].sample
			y = [-1, 0, 1].sample
		end
		dist = rand(1..6)
		t_x += dist * x
		t_y += dist * y
		move_to! t_x, t_y
	end

	def scatter_kickoff! coords=pos
		t_x, t_y = coords
		x, y = 0, 0
		while [x, y] == [0, 0]
			x = [-1, 0, 1].sample
			y = [-1, 0, 1].sample
		end
		dist = rand(1..6)
		t_x += dist * x
		t_y += dist * y
		move_to! t_x, t_y
	end

	def update
		ms = $window.milliseconds_since_last_tick rescue nil
		unless [@target_x, @target_y] == screen_pos
			tmp = to_screen_coords pos
			@last_x, @last_y = @x, @y if @pitch.collision_at? tmp[0], tmp[1]
			d = dist [@target_x, @target_y], [@x, @y], :cartesian

			vx = (@target_x - @x) / d * @velocity * ms
			vy = (@target_y - @y) / d * @velocity * ms

			if (@x - @target_x).abs < 5 then @x = @target_x else @x = @x + vx end
			if (@y - @target_y).abs < 5 then @y = @target_y else @y = @y + vy end

			if [@target_x, @target_y] == [@x, @y]
				x, y = to_pitch_coords [@x, @y]
				@square_entered_listener.call(x, y) if @square_entered_listener
				@pitch_left_listener.call if @pitch_left_listener unless @pitch.collision_at?(@x, @y)
				@pitch.unlock
			end
		end
	end

	def on_square_entered &block
		@square_entered_listener = block
	end

	def on_pitch_left &block
		@pitch_left_listener = block
	end
end
