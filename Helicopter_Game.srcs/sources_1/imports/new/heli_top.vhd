--Main file for Helicopter game logic.
--Tom Dale,Davis Mariotti, Andrew Peacock
--
--includes heli_top: calculates position of helicopter and walls, communicates with users button, vga_sync, and font_unit
--manages collisions, timer, reset, gameOver, and freeze

library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;
entity heli_top is
    Port (
        clk, reset: in std_logic;
        hsync, vsync: out std_logic;
        red: out std_logic_vector(3 downto 0);
        green: out std_logic_vector(3 downto 0);
        blue: out std_logic_vector(3 downto 0);
        btn: in std_logic;
        playAgain, freeze: in std_logic
    );
end heli_top;

architecture heli_top of heli_top is

    constant TVU: integer := 7;  -- Terminal velocity up
    constant TVD: integer:= 7;   -- Terminal velocity down
   
    type wall_data is array(0 to 31) of integer range 0 to 240;

    signal pixel_x, pixel_y: std_logic_vector(9 downto 0);
    signal general_up: std_logic := '0'; -- walls will genrally move up the screen if true
    signal cave_width: integer := 400;
    signal general_width_up: std_logic := '0';
    signal video_on, pixel_tick: std_logic;
    signal red_reg, red_next: std_logic_vector(3 downto 0) := (others => '0');
    signal green_reg, green_next: std_logic_vector(3 downto 0) := (others => '0');
    signal blue_reg, blue_next: std_logic_vector(3 downto 0) := (others => '0'); 
    signal x : integer := 115; --constant helicopter x position
    signal y : integer := 150; --initial helicopter y position
    signal velocity_y : integer := 0;
    signal heli_top, heli_bottom, heli_left, heli_right : integer := 0; 
    signal update_pos, update_vel, update_walls : std_logic := '0'; 
    signal walls: wall_data;
    signal game_over_pause: std_logic := '0'; --true when game is over. press reset to play again
    signal start_pause: std_logic := '1';
    signal row_offset: integer := 0;
    signal column_offset: integer := 0;
    signal number: integer := 0;
    signal score: integer range 0 to 999 := 0;
    signal score1: integer range 0 to 9 := 0;--single character portions of total score
    signal score2: integer range 0 to 9 := 0;
    signal score3: integer range 0 to 9 := 0;
    signal score4: integer range 0 to 9 := 0;
    signal number_return_data: std_logic;
begin
   -- instantiate VGA sync circuit
vga_sync_unit: entity work.vga_sync
    port map(clk=>clk, btn=> btn,playAgain => playAgain, reset=>reset, hsync=>hsync,
            vsync=>vsync, video_on=>video_on,
            pixel_x=>pixel_x, pixel_y=>pixel_y,
            p_tick=>pixel_tick);
font_unit: entity work.font_rom
  port map(data=>number_return_data, column_offset=>column_offset, number=>number, row_offset=>row_offset);
                       
    heli_left <= x;--helicopter doesnt move in x direction, only up and down
    heli_right <= x + 23;            
    heli_top <= y;
    heli_bottom <= y + 16;
    
    -- process to generate update position, velocity, walls, and increment score
    process ( video_on )
        variable counter : integer := 0;
        variable vel_counter : integer := 0;
        variable wall_counter: integer := 0;
        variable score_counter: integer := 0;
        variable game_over_counter: integer := 0;
    begin
        if game_over_pause = '1' then
            score <= 0;
        elsif (rising_edge(video_on) and freeze = '0') and game_over_pause = '0' then
            if start_pause = '0' then
                counter := counter + 1;
                vel_counter := vel_counter + 1;
                wall_counter := wall_counter + 1;
                score_counter := score_counter + 1;
                
                if counter > 1000 then --update postion every 2000 clocks
                    counter := 0;
                    update_pos <= '1';
                else
                    update_pos <= '0';
                end if;
                if vel_counter > 2000 then --update velocity every 2000 clocks
                    vel_counter := 0;
                    update_vel <= '1';
                else
                    update_vel <= '0';
                end if;
                if wall_counter > 10000 then --walls increment every 10000 clocks
                    wall_counter := 0;
                    update_walls <= '1';
                else
                    update_walls <= '0';
                end if;
                if score_counter > 5000 then --scores incrment every 5000 clocks
                    score <= score + 1;
                    score1 <= score mod 10;
                    score2 <= (score / 10) mod 10;
                    score3 <= (score / 100) mod 10;
                    score4 <= (score / 1000) mod 10;
                    score_counter := 0;
                end if;
            elsif btn = '1' then
                start_pause <= '0';
            end if;
         end if;
    end process;

    -- compute the helicopter's position
    process (playAgain, update_pos, video_on)
    begin
        if game_over_pause = '1' and playAgain = '1' then
            game_over_pause <= '0';
        elsif game_over_pause = '1' and playAgain = '0' then
        elsif rising_edge(update_pos) then
            y <= y + velocity_y;
            if (heli_bottom >= cave_width + walls(6)) then -- calculate collision with walls
                y <= walls(7) + 50;
                game_over_pause <= '1';
            elsif (heli_top <= walls(6))then
                y <= walls(7) + 50;
                game_over_pause <= '1';
            end if;
        end if; 
    end process;
    

    -- compute the helicopter's velocity
    process (update_vel)
    begin
        if rising_edge(update_pos) then
            if btn = '1' then
                if velocity_y > -TVU then
                    velocity_y <= velocity_y - 1;
                end if;
            else
                if velocity_y < TVD then
                    velocity_y <= velocity_y + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Shift walls and compute psuedo-psuedo-random new wall
    process (update_walls)
    begin
        if rising_edge(update_walls)  then
            if (cave_width < 100) then--randomly change difficulty by changing cave_width
                cave_width <= 105;
                general_width_up <= '1';
            elsif (cave_width > 300) then
                cave_width <= 295;
                general_width_up <= '0';
            elsif (general_width_up = '1') then 
                cave_width <= cave_width + 1;
            else
                cave_width <= cave_width - 1;
            end if;
            for i in 1 to 31 loop
                walls(i - 1) <= walls(i);
            end loop;
            --calculate random change in far right wall
            if(walls(31) < 31) then 
                general_up <= '1';
                walls(31) <= 35;
            elsif (walls(31) >= 230) then
                general_up <= '0';
                 walls(31) <= 225;
            elsif(general_up = '1')then --should walls generally move up or down
                 walls(31) <= walls(31)+ ((walls(2) * walls(19) + walls(25) * 13) mod 40) -10; --add value between -10 and 30
                 if((heli_top + walls(2))*13 mod 10 = 1) then--10 % of the time change general wall direction
                    general_up <= '0';
                    end if;
            else
                walls(31) <= walls(31)- ((walls(2) * walls(19) + walls(25) * 13) mod 40) +10; --add value between -30 and 10
                if((heli_top + walls(2))*13 mod 10 = 1) then --10 % of the time change general wall direction
                    general_up <= '1';
                    end if;
           end if;
        end if;
    end process;      
    
    -- process to generate next colors     
    process (pixel_x, pixel_y)        
    type heli_sprite is array (0 to 15) of std_logic_vector(0 to 22);
    
    variable heli_data : heli_sprite := (-- helicopter bits
        "0011110000000000001111",
        "00000011110000011110000",
        "00000000001111100000000",
        "00000000000010000000000",
        "00000000000010000000000",
        "00000000001111111100000",
        "10100000011000010011000",
        "01011111100111010001100",
        "10100001000101010000100",
        "00000001000111011111110",
        "00000001000000000000010",
        "00000000100000000000010",
        "00000000011111111111100",
        "00000000000010000100000",
        "00000000000010000100000",
        "00000000111111111111110"
    );
    variable pos_in_heli_x: integer := to_integer(signed(pixel_x)) - heli_left;
    variable pos_in_heli_y: integer := to_integer(signed(pixel_y)) - heli_top;
    variable draw_pixel: std_logic := '0';
    begin
        draw_pixel := '0';
        if (unsigned(pixel_x) >= heli_left) and (unsigned(pixel_x) < heli_right) and
        (unsigned(pixel_y) >= heli_top) and (unsigned(pixel_y) < (heli_bottom)) and
        (heli_data(pos_in_heli_y)(pos_in_heli_x) = '1') then
            red_next <= "1111"; -- White helicopter
            green_next <= "1111";
            blue_next <= "1111";
        else    
            -- background color blue
            red_next <= "0000";
            green_next <= "0000";
            blue_next <= "1111";
        end if;
        -- calculate where to draw walls
        for I in 0 to 31 loop
            if ((unsigned(pixel_x) < 23*I)and (unsigned(pixel_x) >= 23*(I-1))) and ((unsigned(pixel_y) < walls(I) or (unsigned(pixel_y) > cave_width +  walls(I)))) then
                red_next <= "1111";
                green_next <= "0010";
                blue_next <= "0010";
            end if;
        end loop;
        --draw scores to screen, must be separated by individual digits
        if (unsigned(pixel_x) >= 520) and (unsigned(pixel_y) > 456) then
            row_offset <= to_integer(signed(pixel_y)) - 460;
            if (unsigned(pixel_x) >= 627) and (unsigned(pixel_x) < 635) and -- Score far right
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 627;
                number <= score1;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 617) and (unsigned(pixel_x) < 625) and -- Score second right
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 617;
                number <= score2;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 607) and (unsigned(pixel_x) < 615) and -- Score third right
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 607;
                number <= score3;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 597) and (unsigned(pixel_x) < 605) and -- Score far left
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 597;
                number <= score4;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
                --below is "score:" printed to screen
            elsif (unsigned(pixel_x) >= 582) and (unsigned(pixel_x) < 590) and -- :
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 582;
                number <= 15;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 572) and (unsigned(pixel_x) < 580) and -- e
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 572;
                number <= 14;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 562) and (unsigned(pixel_x) < 570) and -- r
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 562;
                number <= 13;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 552) and (unsigned(pixel_x) < 560) and -- o
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 552;
                number <= 12;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 542) and (unsigned(pixel_x) < 550) and -- c
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 542;
                number <= 11;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 532) and (unsigned(pixel_x) < 540) and -- S
                (unsigned(pixel_y) >= 460) and (unsigned(pixel_y) < 476) then
                column_offset <= to_integer(signed(pixel_x)) - 532;
                number <= 10;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            end if;
            if (draw_pixel = '1') then
                -- RED
                red_next <= "1111"; 
                green_next <= "0010";
                blue_next <= "0010";
            else
                red_next <= "0000";
                green_next <= "0000";
                blue_next <= "0000";
            end if;
            --draw game over
        elsif (unsigned(pixel_x) >= 272) and (unsigned(pixel_x) < 365) and -- game over screen center
            (unsigned(pixel_y) > 228) and (unsigned(pixel_y) < 252) and game_over_pause = '1' then
            row_offset <= to_integer(signed(pixel_y)) - 232;
            if (unsigned(pixel_x) >= 276) and (unsigned(pixel_x) < 284) and -- r
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 276;
                number <= 16;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 286) and (unsigned(pixel_x) < 294) and -- e
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 286;
                number <= 17;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 296) and (unsigned(pixel_x) < 304) and -- v
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 296;
                number <= 18;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 306) and (unsigned(pixel_x) < 314) and -- O
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 306;
                number <= 19;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 320) and (unsigned(pixel_x) < 328) and -- E
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 320;
                number <= 20;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 330) and (unsigned(pixel_x) < 338) and -- M
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 330;
                number <= 21;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 340) and (unsigned(pixel_x) < 348) and -- A
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 340;
                number <= 19;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            elsif (unsigned(pixel_x) >= 350) and (unsigned(pixel_x) < 358) and -- G
                (unsigned(pixel_y) >= 232) and (unsigned(pixel_y) < 248) then
                column_offset <= to_integer(signed(pixel_x)) - 350;
                number <= 22;
                if number_return_data = '1' then
                    draw_pixel := '1';
                end if;
            end if;
            if (draw_pixel = '1') then
                -- RED
                red_next <= "1111"; 
                green_next <= "0010";
                blue_next <= "0010";
            else
                red_next <= "0000";
                green_next <= "0000";
                blue_next <= "0000";
            end if;
        end if;
    end process;

  -- generate r,g,b registers
   process ( video_on, pixel_tick, red_next, green_next, blue_next)
   begin
      if rising_edge(pixel_tick) then
          if (video_on = '1') then
            red_reg <= red_next;
            green_reg <= green_next;
            blue_reg <= blue_next;   
          else
            red_reg <= "0000";
            green_reg <= "0000";
            blue_reg <= "0000";                    
          end if;
      end if;
   end process;
   
   red <= STD_LOGIC_VECTOR(red_reg);
   green <= STD_LOGIC_VECTOR(green_reg); 
   blue <= STD_LOGIC_VECTOR(blue_reg);
   
--   function in_wall_section(px : integer) return std_logic is
--   begin
   
--   end in_wall_section;

end heli_top;
