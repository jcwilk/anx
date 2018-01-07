-- START LIB
orig_field_of_view=1/6
field_of_view=orig_field_of_view -- 45*
orig_draw_distance=10
draw_distance=orig_draw_distance
orig_height_ratio=.6
height_ratio=orig_height_ratio
distance_from_player_cutoff=.4
mob_hitbox_radius=.45 -- this should be less than .5 but more than distance_from_player_cutoff
height_scale=20 -- multiplier for something at distance of one after dividing by field of view
orig_turn_amount=.01
turn_amount=orig_turn_amount
orig_speed = .1
speed = orig_speed
max_anxiety = 40

--debug stuff, disable for release
force_draw_width=false
skip_update=false
skip_draw=false
debug=false
--

function draw_debug()
  color(12)
  cursor(0,0)
  print(stat(0))
  print(draw_start_time)
  print(presort_time)
  print(predraw_time)
  print(stat(1))
  print(stat(7))
  print("x"..player.coords.x.." y"..player.coords.y)
  print(player.bearing.val)
  print(1-skipped_columns/128)
  print(largest_width)
end

function set_skybox(sprite_id)
  sky_color=sget(8*(sprite_id%16),8*flr(sprite_id/16))
  ground_color=sget(8*(sprite_id%16),8*flr(sprite_id/16)+4)
end

--borrowed with love from https://www.lexaloffle.com/bbs/?pid=40157#p40157
function ce_heap_sort(data)
 local n = #data
 if n == 0 then
  return
 end

 -- form a max heap
 for i = flr(n / 2) + 1, 1, -1 do
  -- m is the index of the max child
  local parent, value, m = i, data[i], i + i
  local key = value.key

  while m <= n do
   -- find the max child
   if ((m < n) and (data[m + 1].key > data[m].key)) m += 1
   local mval = data[m]
   if (key > mval.key) break
   data[parent] = mval
   parent = m
   m += m
  end
  data[parent] = value
 end

 -- read out the values,
 -- restoring the heap property
 -- after each step
 for i = n, 2, -1 do
  -- swap root with last
  local value = data[i]
  data[i], data[1] = data[1], value

  -- restore the heap
  local parent, terminate, m = 1, i - 1, 2
  local key = value.key

  while m <= terminate do
   local mval = data[m]
   local mkey = mval.key
   if (m < terminate) and (data[m + 1].key > mkey) then
    m += 1
    mval = data[m]
    mkey = mval.key
   end
   if (key > mkey) break
   data[parent] = mval
   parent = m
   m += m
  end

  data[parent] = value
 end
end

function reset_wall_cache()
  wall_cache={{},{}}
end

function cache_wall_col(x,y,face_index)
  if not wall_cache[face_index][x] then
    wall_cache[face_index][x] = {}
  end

  if not wall_cache[face_index][x][y] then
    wall_cache[face_index][x][y] = {}
  end

  return wall_cache[face_index][x][y]
end

largest_width=0
max_screenx_offset=0
skipped_columns=0
function raycast_walls()
  local pv
  local slope
  local seenwalls={}
  local currx,curry,found,xdiff,ydiff,sprite_id,intx,inty,xstep,ystep,distance,drawn_fog
  wall_pool=make_pool()
  screenx=0
  buffer_percent=.2
  local start_time=draw_start_time

  local total_time
  if changed_position then
    total_time=1
  else
    total_time=2
  end
  --total_time-=.25

  local alotted_time=total_time-start_time
  local buffer_time=buffer_percent*alotted_time
  start_time+=buffer_time
  alotted_time-=buffer_time

  skipped_columns=0 --global for debug
  local found_mobs
  local new_draw --, deferred_draws
  local draw_width
  local last_tile_occupied
  local this_wall_cache, face_index
  largest_width=0
  clear_draw_cache()
  reset_wall_cache()
  deferred_draws={}
  found_mobs={}

  while screenx<=127 do
    behind_time=stat(1)-(start_time+screenx/127*alotted_time-buffer_time-.002*#deferred_draws)
    draw_width=128*behind_time/alotted_time
    draw_width=flr(mid(1,8,draw_width))
    if force_draw_width then
      draw_width=force_draw_width
    end
    largest_width=max(largest_width,draw_width)
    skipped_columns+=draw_width-1

    last_tile_occupied=false

    pa=screenx_to_angle(screenx+(draw_width-1)/2)
    pv=pa:tovector()

    currx=round(player.coords.x)
    curry=round(player.coords.y)
    found=false
    xstep = towinf(pv.x)
    ystep = towinf(pv.y)
    drawn_fog=false

    if abs(pv.x) > abs(pv.y) then
      intx= currx - xstep/2
      distance = (intx - player.coords.x) / pv.x
      inty= player.coords.y + distance * pv.y
    else
      inty= curry - ystep/2
      distance = (inty - player.coords.y) / pv.y
      intx= player.coords.x + distance * pv.x
    end

    while not found do
      if (currx + xstep/2 - intx) / pv.x < (curry + ystep/2 - inty) / pv.y then
        intx= currx + xstep/2
        distance = (intx - player.coords.x) / pv.x
        inty= player.coords.y + distance * pv.y
        currx+= xstep
        reversed=xstep>0
        face_index=1
      else
        inty= curry + ystep/2
        distance = (inty - player.coords.y) / pv.y
        intx= player.coords.x + distance * pv.x
        curry+= ystep
        reversed=ystep<0
        face_index=2
      end

      if distance > draw_distance * .85 and not drawn_fog then
        new_draw=deferred_fog_draw(pa,draw_distance*.9,draw_width,screenx)
        if new_draw then
          drawn_fog=true
          add(deferred_draws,new_draw)
        end
      end

      if (distance > draw_distance) then
        found=true
        new_draw=deferred_fog_draw(pa,draw_distance,draw_width,screenx,true)
        if new_draw then
          add(deferred_draws,new_draw)
        end
      else
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

            this_wall_cache = cache_wall_col(currx,curry,face_index)
            new_draw = this_wall_cache[pixel_col]
            if new_draw then
              new_draw:add_hit(distance,screenx,draw_width)
            else
              new_draw=deferred_wall_draw(pa,distance,sprite_id,pixel_col,draw_width,screenx,draw_width)
              if new_draw then
                add(deferred_draws,new_draw)
                this_wall_cache[pixel_col] = new_draw
              end
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
                add(deferred_draws,new_draw)
              end
            end
          end
        end
      end
    end

    if debug and draw_width>1 then
      line(screenx+1,127,screenx+draw_width-1,127,8)
    end

    screenx+=draw_width
  end

  presort_time=stat(1)
  ce_heap_sort(deferred_draws)
  predraw_time=stat(1)
  for d in all(deferred_draws) do
    d:draw()
  end
end

mobile_pool = make_pool()
wall_pool = make_pool()
player =makemobile(false,makevec2d(10.369,-33.525),makeangle(.6601))

for x=0,127 do
  for y=0,63 do
    mob_id=mget(x,y)
    if is_sprite_mob(mob_id) then
      if mob_id == 17 then
        mobile_pool.make(makecoin(mob_id,makevec2d(x,-y),makeangle(rnd())))
      elseif mob_id == 16 then
        mobile_pool.make(makewhisky(mob_id,makevec2d(x,-y),makeangle(rnd())))
      else
        mobile_pool.make(makemobile(mob_id,makevec2d(x,-y),makeangle(rnd())))
      end
    end
  end
end

reverse_strafe=false
menuitem(1, "reverse strafe", function()
  reverse_strafe = not reverse_strafe
end)

--debug=true
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

  is_panic_attack = false

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

visual_anxiety = current_anxiety
max_anxiety_diff = .3
function recalc_settings()
  -- if current_anxiety == 0 and visual_anxiety == 0 then
  --   if ran_one_last_time then
  --     return
  --   else
  --     ran_one_last_time = true
  --   end
  -- else
  --   ran_one_last_time = false
  -- end

  local anxiety_diff = current_anxiety - visual_anxiety
  local max_diff = max(abs(anxiety_diff/10),max_anxiety_diff)
  visual_anxiety+= mid(-max_anxiety_diff,anxiety_diff,max_anxiety_diff)

  -- https://www.desmos.com/calculator/pfberbcv2c
  local downscale_anxiety = .4 --sliding scale for how intense to make it
  local anxiety_factor = -2/(-visual_anxiety*downscale_anxiety-2)
  fisheye_ratio = (1 - anxiety_factor) * 3
  --field_of_view = orig_field_of_view / anxiety_factor
  height_ratio = .44+.08*abs(sin(walking_step))+.15*anxiety_factor
  draw_distance = orig_draw_distance * (1/4 + 3/4*anxiety_factor)
  turn_amount = orig_turn_amount * (2 - anxiety_factor)
  height_ratio = orig_height_ratio * (.8 + anxiety_factor*.2)
  speed = orig_speed * (2 - anxiety_factor)
  if is_panic_attack then
    enable_anxiety_x_offset = true
    max_screenx_offset = 80
  else
    enable_anxiety_x_offset = false
    max_screenx_offset = (1 - anxiety_factor)
  end
  if true then
    return
  end
  --TODO
  --wander_aom()
end

function add_anxiety()
  current_anxiety+=3
  if current_anxiety >= max_anxiety then
    current_anxiety = max_anxiety
    is_panic_attack = true
  end
  anxiety_recover_cooldown = 3
end

function _update()
  if skip_update then
    return
  end
  local offset = makevec2d(0,0)
  local facing = player.bearing:tovector()
  local right = makevec2d(facing.y,-facing.x)
  if reverse_strafe then
    right*=-1
  end
  changed_position=false
  if btn(0) then
    changed_position=true
    player.bearing-=turn_amount
  end
  if btn(1) then
    changed_position=true
    player.bearing+=turn_amount
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

  player:apply_movement(offset*speed)



  local curr_tile_sprite_id=mget(round(player.coords.x),round(-player.coords.y))
  if is_sprite_door(curr_tile_sprite_id) then
    need_new_skybox=true
  elseif is_sprite_skybox(curr_tile_sprite_id) then
    set_skybox(curr_tile_sprite_id)
  end




  tick_anxiety()

  tick_bearing_v()

  recalc_settings()

  --USAGE ~.035
  mobile_pool:each(function(m)
    m:update()
  end)

  update_fog_swirl()
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
end

function draw_anxiety_bar()
  rectfill(54,1,126,6,0)
  rectfill(83,2,125,5,1)
  if current_anxiety > 0 then
    local anx_pixels = (125-83) / max_anxiety * current_anxiety
    rectfill(83,2,min(83+anx_pixels,125),5,7)
    local disp_pixels
    if is_panic_attack then
      disp_pixels = 125-83
    else
      disp_pixels = (125-83) / max_anxiety * visual_anxiety
    end
    rectfill(83,2,min(83+disp_pixels,125),5,8)
    print("ANXIETY",55,1,6)
  else
    print("ANXIETY",55,1,5)
  end
end

coin_count=0
function add_coin()
  coin_count+=1
end

function clear_coins()
  coin_count=0
end

has_whisky=false
function add_whisky()
  has_whisky=true
end

function draw_inventory()
  for i=0,coin_count do
    spr(17,128-i*9,8)
  end
  if has_whisky then
    spr(16,128-coin_count*9-8,8) -- -8 because the whisky is a little narrow
  end
end

mob_pos_map={}
sky_color=1
ground_color=0
fog_color=0
function _draw()
  draw_start_time = stat(1)
  if (skip_draw) then
    cls()
  else
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

    draw_anxiety_bar()

    draw_inventory()
  end

  if debug then
    draw_debug()
  end
end
-- END LIB
