require "chingu"
include Chingu
include Gosu

require "helpers/measures"

class PostCombatState < GameState
	include Helpers::Measures

	def initialize options = {}
		super
		self.input = { :mouse_right => :click }

		@attacker = options[:attacker]
		@defender = options[:defender]

		push      = options[:push] || true

		if push and @defender.on_pitch?
			@areas = {
				[-1, -1] => [[ 0,  1], [ 1,  0], [ 1,  1]],
				[-1,  0] => [[ 1, -1], [ 1,  0], [ 1,  1]],
				[-1,  1] => [[ 0, -1], [ 1, -1], [ 1,  0]],
				[ 0, -1] => [[-1,  1], [ 0,  1], [ 1,  1]],
				[ 1,  1] => [[-1,  0], [-1, -1], [ 0, -1]],
				[ 0,  1] => [[-1, -1], [ 0, -1], [ 1, -1]],
				[ 1, -1] => [[-1,  0], [-1,  1], [ 0,  1]],
				[ 1,  0] => [[-1, -1], [-1,  0], [-1,  1]]
			}

			@squares   = []
			x,y = @defender.pos
			corner = [@attacker.pos[0] - x, @attacker.pos[1] - y]
			@areas[corner].each do |a,b|
				pos = to_screen_coords [x+a, y+b]
				@squares << Square.create(:x => pos[0], :y => pos[1], :type => :square, :color => :blue, :zorder => 2)
			end
		else
			show_menu
		end
	end

	def update
		super
		previous_game_state.update
		$window.change_cursor :normal
	end

	def draw
		super
		previous_game_state.draw
		if @menu then $window.fill_rect([0, 0, $window.width, $window.height], 0xAA000000, 200) end
	end

	def click
		clicked_square = false
		@squares.each do |square|
			if square.collision_at? $window.mouse_x, $window.mouse_y
				x, y = to_pitch_coords [$window.mouse_x, $window.mouse_y]
				@defender_last_pos = @defender.pos
				show_menu if @defender.push_to! x, y
			end
		end
	end

	def show_menu
		@squares.each { |square| square.destroy! } if @squares
		Text.create "Do you want to follow?", :x => $window.width / 2.0 - 120, :y => $window.height / 2.0 + 40, :zorder => 205

		items = { "Yes" => :follow, "No" => :close }.sort_by { |key,value| key }
		@menu = Menu.create :menu_items => items,
		                    :x => $window.width / 2.0,
		                    :y => $window.height / 2.0,
		                    :zorder => 200,
		                    :select_color => 0xFF0056D6,
		                    :unselect_color => 0xFFFFFFFF,
		                    :spacing => 30,
		                    :bg_padding_r => 5,
		                    :bg_padding_l => 5,
		                    :bg_padding_t => 30,
		                    :bg_padding_b => 5,
		                    :anchor => :center_center,
		                    :font => "media/fonts/averia_rg.ttf",
		                    :font_size => 35,
		                    :orientation => :horizontal
	end

	def follow
		x, y = @defender.pos
		x, y = @defender_last_pos if @defender_last_pos

		@attacker.push_to! x, y
		close
	end
end
