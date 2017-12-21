-- START LIB
orig_field_of_view=1/6
field_of_view=orig_field_of_view -- 45*
orig_draw_distance=12
draw_distance=orig_draw_distance
height_ratio=.6
distance_from_player_cutoff=.4
mob_hitbox_radius=.45 -- this should be less than .5 but more than distance_from_player_cutoff
height_scale=20 -- multiplier for something at distance of one after dividing by field of view

function set_skybox(sprite_id)
  sky_color=sget(8*(sprite_id%16),8*flr(sprite_id/16))
  ground_color=sget(8*(sprite_id%16),8*flr(sprite_id/16)+4)
end

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
  local new_draw, deferred_draws
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
    deferred_draws=make_pool()
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
      if is_sprite_wall(sprite_id) then
        if not is_sprite_wall_transparent(sprite_id) then
          found=true
        end

        if found or not last_tile_occupied or (last_tile_occupied != sprite_id and is_sprite_wall_transparent(sprite_id)) then
          pixel_col=flr(((intx+inty)%1)*8)
          if reversed then
            pixel_col=7-pixel_col
          end
          new_draw=deferred_wall_draw(intx,inty,sprite_id,pixel_col,draw_width)
          if new_draw then
            deferred_draws.make(new_draw)
          end
        end
        last_tile_occupied=sprite_id
      else
        if need_new_skybox and is_sprite_skybox(sprite_id) then
          need_new_skybox=false
          set_skybox(sprite_id)
        end
        last_tile_occupied=false
      end
      if not found and mob_pos_map[currx] and mob_pos_map[currx][curry] then
        for mobi in all(mob_pos_map[currx][curry]) do
          if not found_mobs[mobi.id] then
            new_draw=mobi:deferred_draw(pv,screenx,draw_width)
            if new_draw then
              found_mobs[mobi.id]=true
              deferred_draws.make(new_draw)
            end
          end
        end
      end
    end

    deferred_draws:sort_by(function(d)
      return d.distance
    end)

    deferred_draws:each(function(d)
      d.draw()
    end)

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
    if is_sprite_mob(mob_id) then
      mobile_pool.make(makemobile(mob_id,makevec2d(x,-y),makeangle(rnd())))
    end
  end
end

reverse_strafe=false
menuitem(1, "reverse strafe", function()
  reverse_strafe = not reverse_strafe
end)

menuitem(3, "debug", function()
  if debug then
    debug = false
  else
    debug = true
  end
end)

current_anxiety=0
anxiety_recover_cooldown=0
function tick_anxiety()
  if anxiety_recover_cooldown > 0 then
    anxiety_recover_cooldown -= 1/30
    return
  end

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
  local downscale_anxiety = .4 --sliding scale for how intense to make it
  local anxiety_factor = -2/(-current_anxiety*downscale_anxiety-2)
  fisheye_ratio = (1 - anxiety_factor) * 4
  --field_of_view = orig_field_of_view / anxiety_factor
  height_ratio = .44+.08*abs(sin(walking_step))+.15*anxiety_factor
  draw_distance = orig_draw_distance * (1/4 + 3/4*anxiety_factor)
end

function nudge_player(angle)
  --player_bearing_v+=angle/30+tounit(angle)/100
end

function add_anxiety(angle)
  current_anxiety+=3
  anxiety_recover_cooldown = 3
  nudge_player(angle)
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

  local curr_tile_sprite_id=mget(round(player.coords.x),round(-player.coords.y))
  if is_sprite_door(curr_tile_sprite_id) then
    need_new_skybox=true
  elseif is_sprite_skybox(curr_tile_sprite_id) then
    set_skybox(curr_tile_sprite_id)
  end

  tick_anxiety()
  tick_bearing_v()
  recalc_settings()

  mobile_pool:each(function(m)
    m:update()
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

function draw_background()
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
end

mob_pos_map={}
sky_color=1
ground_color=0
fog_color=0
function _draw()
  draw_background()

  mob_pos_map={}
  mobile_pool:each(function(mob)
    for x=flr(mob.coords.x),ceil(mob.coords.x) do
      for y=flr(mob.coords.y),ceil(mob.coords.y) do
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
    print(player.bearing.val)
  end
end
-- END LIB
