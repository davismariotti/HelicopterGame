

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
        btn: in std_logic
    );
end heli_top;

architecture heli_top of heli_top is

   constant TVU: integer := 15;   --Terminal velocity up
   constant TVD: integer:= 7;   -- Terminal velocity down

    signal pixel_x, pixel_y: std_logic_vector(9 downto 0);
    signal video_on, pixel_tick: std_logic;
    signal red_reg, red_next: std_logic_vector(3 downto 0) := (others => '0');
    signal green_reg, green_next: std_logic_vector(3 downto 0) := (others => '0');
    signal blue_reg, blue_next: std_logic_vector(3 downto 0) := (others => '0'); 
    signal x : integer := 300;
    signal y : integer := 300;
    signal velocity_y : integer := 0;
    signal heli_top, heli_bottom, heli_left, heli_right : integer := 0; 
    signal update_pos, update_vel : std_logic := '0'; 
begin
   -- instantiate VGA sync circuit
vga_sync_unit: entity work.vga_sync
    port map(clk=>clk, btn=> btn, reset=>reset, hsync=>hsync,
            vsync=>vsync, video_on=>video_on,
            pixel_x=>pixel_x, pixel_y=>pixel_y,
            p_tick=>pixel_tick);
                
    heli_left <= x;
    heli_right <= x + 20;            
    heli_top <= y;
    heli_bottom <= y + 20;
    
    -- process to generate update position signal
    process ( video_on )
        variable counter : integer := 0;
    begin
        if rising_edge(video_on) then
            counter := counter + 1;
            if counter > 1000 then
                counter := 0;
                update_pos <= '1';
            else
                update_pos <= '0';
            end if;
         end if;
    end process;
    
    process ( video_on )
        variable vel_counter : integer := 0;
    begin
        if rising_edge(video_on) then
            vel_counter := vel_counter + 1;
            if vel_counter > 2000 then
                vel_counter := 0;
                update_vel <= '1';
            else
                update_vel <= '0';
            end if;
         end if;
    end process;
    

    -- compute the helicopter's position
    process (update_pos)
    begin
        if rising_edge(update_pos) then 
            x <= 300;
            y <= y + velocity_y;
            if (heli_bottom >= 479) and (velocity_y > 0) then
                y <= 459;
            elsif (heli_top <= 1) and (velocity_y < 0) then
                y <= 1;
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
    
    -- process to generate next colors           
    process (pixel_x, pixel_y)
    begin
           if (unsigned(pixel_x) > heli_left) and (unsigned(pixel_x) < heli_right) and
           (unsigned(pixel_y) > heli_top) and (unsigned(pixel_y) < heli_bottom) then
               -- foreground box color yellow
               red_next <= "1111";
               green_next <= "1111";
               blue_next <= "0000"; 
           else    
               -- background color blue
               red_next <= "0000";
               green_next <= "0000";
               blue_next <= "1111";
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

end heli_top;
