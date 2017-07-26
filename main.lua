-- START LIB
orig_field_of_view=1/4
field_of_view=orig_field_of_view -- 45*
draw_distance=12
height_scale=20 -- multiplier for something at distance of one after dividing by field of view
height_ratio=0.6

start_time=0
max_width=0
function raycast_walls()
  local pv
  local slope
  local seenwalls={}
  local currx,curry,nextx,found,xdiff,ydiff,sprite_id,testy,testx,intx,inty
  wall_pool=make_pool()
  screenx=0
  buffer_percent=.1
  start_time=stat(1)
  local alotted_time
  if changed_position then
    alotted_time=(1-start_time)
  else
    alotted_time=(2-start_time)
  end
  local buffer_time=buffer_percent*alotted_time
  start_time+=buffer_time
  alotted_time-=buffer_time

  local skipped_columns=0
  local found_mobs
  local mob_draw, draw_stack
  local draw_width
  local last_tile_occupied
  max_width=0
  clear_draw_cache()
  while screenx<=127 do
    behind_time=stat(1)-(start_time+screenx/127*alotted_time-buffer_time)
    draw_width=128*behind_time/alotted_time
    draw_width=flr(mid(1,8,draw_width))
    max_width=max(max_width,draw_width)
    skipped_columns+=draw_width-1

    last_tile_occupied=false

    pv=screenx_to_angle(screenx+(draw_width-1)/2):tovector()

    xdiff=towinf(pv.x)
    ydiff=towinf(pv.y)
    if abs(pv.x) < .001 then
      slope = false
    else
      slope=pv.y/pv.x
      slope_y_correction=player.coords.y-slope*player.coords.x
    end
    currx=round(player.coords.x)
    curry=round(player.coords.y)
    found=false
    count=1
    draw_stack={}
    found_mobs={}

    while not found and count <= draw_distance do
      count+=1
      reversed=false
      if not slope then
        curry+=ydiff
        intx=player.coords.x
        inty=curry-ydiff/2
        if ydiff<0 then
          reversed=true
        end
      else
        nextx=currx+xdiff
        testy=slope*(nextx-xdiff/2)+slope_y_correction
        if round(testy) == curry then
          currx=nextx
          intx=currx-xdiff/2
          inty=testy
          if xdiff>0 then
            reversed=true
          end
        else
          curry+=ydiff
          intx=(curry-ydiff/2-slope_y_correction)/slope
          inty=curry-ydiff/2
          if ydiff<0 then
            reversed=true
          end
        end
      end

      sprite_id=mget(currx,-curry)
      if sprite_id > 0 and not fget(sprite_id,7) then
        if not fget(sprite_id,0) then
          found=true
        end

        if found or not last_tile_occupied or (last_tile_occupied != sprite_id and fget(last_tile_occupied,3)) then
          pixel_col=flr(((intx+inty)%1)*8)
          if reversed then
            pixel_col=7-pixel_col
          end
          add(draw_stack,deferred_wall_draw(intx,inty,sprite_id,pixel_col,draw_width))
        end
        last_tile_occupied=sprite_id
      else
        last_tile_occupied=false
      end
      if not found and mob_pos_map[currx] and mob_pos_map[currx][curry] then
        for mobi in all(mob_pos_map[currx][curry]) do
          if not found_mobs[mobi.id] then
            mob_draw=mobi:deferred_draw(pv,screenx,draw_width)
            if mob_draw then
              found_mobs[mobi.id]=true
              add(draw_stack,mob_draw)
            end
          end
        end
      end
    end

    for stack_i=#draw_stack,1,-1 do
      draw_stack[stack_i]()
    end

    if debug and draw_width>1 then
      line(screenx+1,127,screenx+draw_width-1,127,8)
    end

    screenx+=draw_width
  end
  if debug then
    color(12)
    print(1-skipped_columns/128)
    print(max_width)
  end
end

mobile_pool = make_pool()
wall_pool = make_pool()
player =makemobile(false,makevec2d(8,-30),makeangle(-1/4))

for x=0,127 do
  for y=0,63 do
    mob_id=mget(x,y)
    if fget(mob_id,7) then
      mobile_pool.make(makemobile(mob_id,makevec2d(x,-y),makeangle(rnd())))
    end
  end
end

reverse_strafe=false
menuitem(1, "reverse strafe", function()
  reverse_strafe = not reverse_strafe
end)

menuitem(2, "debug", function()
  if debug then
    debug = false
  else
    debug = true
  end
end)

current_anxiety=0
function tick_anxiety()
  if current_anxiety >= 0 then
    current_anxiety-=.05+.005*current_anxiety
    if current_anxiety < 0 then current_anxiety=0 end
  end
end

player_bearing_v=0
function tick_bearing_v()
  if abs(player_bearing_v) > .0005 then
    player_bearing_v-= tounit(player_bearing_v)*.0005
    player.bearing+=player_bearing_v
  end
end

walking_step=0
function tick_walking()
  walking_step+=.05
  if walking_step >= 1 then walking_step=0 end
end

function recalc_settings()
  -- https://www.desmos.com/calculator/pw8n3n8rwf
  local anxiety_factor = -1/(-.4*current_anxiety-2)+.5
  field_of_view = orig_field_of_view*anxiety_factor
  height_ratio = .44+.08*abs(sin(walking_step))+.15*anxiety_factor
end

function nudge_player()
  if rnd()>.5 then
    player_bearing_v+=.005
  else
    player_bearing_v-=.005
  end
end

function add_anxiety()
  current_anxiety+=3
  nudge_player()
end

function _update()
  local offset = makevec2d(0,0)
  local facing = player.bearing:tovector()
  local right = makevec2d(facing.y,-facing.x)
  if reverse_strafe then
    right*=-1
  end
  changed_position=false
  if btn(0) then
    changed_position=true
    player.bearing-=0.01
  end
  if btn(1) then
    changed_position=true
    player.bearing+=0.01
  end
  if btn(2) then
    offset+=facing
    tick_walking()
  end
  if btn(3) then
    offset-=facing
    tick_walking()
  end
  if btn(4) then
    offset+=right
  end
  if btn(5) then
    offset-=right
  end

  if offset:diamond_distance() > 0 then
    changed_position=true
  end

  player:apply_movement(offset*0.1)

  if player.entering_door == 11 then
    sky_color=1
    ground_color=3
  elseif player.entering_door == 5 then
    sky_color=7
    ground_color=2
  end

  tick_anxiety()
  tick_bearing_v()
  recalc_settings()

  mobile_pool:each(function(m)
    --m.bearing+=.01
    --m:turn_towards_player()
    local m_to_p=m.coords-player.coords
    local distance=m_to_p:tomagnitude()
    if distance < 4 then
      if abs(m:turn_towards_player()) < .1 then
        if distance > 2 then
          m:apply_movement(m_to_p/distance*-.04)
        else
          m:talk()
        end
      end
    end
  end)
end

function draw_stars()
  --TODO fuckin thing sucks
  local x,y,angle
  color(7)
  angle=player.bearing-field_of_view/2
  local init=flr(angle.val*100)
  local final=flr((angle.val+field_of_view)*100)
  for i=init,final do
    pset((i-init)/100/field_of_view*128,64-((i*19)%64)*orig_field_of_view/field_of_view)
  end
end

function sort_by_distance(m)
  return (m.coords-player.coords):diamond_distance()
end

mob_pos_map={}
sky_color=1
ground_color=0
fog_color=0
function _draw()
  rectfill(0,0,127,63,sky_color)
  rectfill(0,64,127,127,ground_color)
  draw_stars()
  local fog_height=height_scale*2/(draw_distance-1)/field_of_view
  local fog_bottom=64-fog_height*(1-height_ratio)
  rectfill(0,fog_bottom,127,fog_bottom+fog_height,ground_color)
  for i=0,127 do
    for j=fog_bottom,fog_bottom+fog_height-1,2 do
      pset(i,j+i%2,sky_color)
    end
  end


  --draw_walls()
  mob_pos_map={}
  mobile_pool:each(function(mob)
    for x=flr(mob.coords.x),flr(mob.coords.x)+1 do
      for y=flr(mob.coords.y),flr(mob.coords.y)+1 do
        mob_pos_map[x] = mob_pos_map[x] or {}
        mob_pos_map[x][y] = mob_pos_map[x][y] or {}
        add(mob_pos_map[x][y],mob)
      end
    end
  end)

  raycast_walls()
  if debug then
    color(12)
    cursor(0,0)
    print(start_time)
    print(stat(1))
    print("x"..player.coords.x.." y"..player.coords.y)
  end
end
-- END LIB