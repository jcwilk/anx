pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
--anx
--by john wilkinson

-- start ext ./utils.lua
function trunc(n)
 return flr(n)
end

function towinf(n) --opposite of truncate
 if n > 0 then
  return -flr(-n)
 else
  return flr(n)
 end
end

function round(n)
 return flr(n+0.5)
end

function tounit(n)
 if n >= 0 then
  return 1
 else
  return -1
 end
end

function noop_f()
end

make_pool = (function()
 local function zip_with(pool,pool2)
  local t1=pool.store
  local t2=pool2.store
  local t3={}
  local t1i=1
  local t2i=1
  local t1v,t2v
  while t1i <= #t1 or t2i <= #t2 do
   if t1i <= #t1 then
    t1v=t1[t1i]._sort_value
   else
    t1v=false
   end
   if t2i <= #t2 then
    t2v=t2[t2i]._sort_value
   else
    t2v=false
   end
   -- print(t1v)
   -- print(t2v)
   if not t2v or (t1v and t1v > t2v) then
    add(t3,t1[t1i])
    t1i+=1
   else
    add(t3,t2[t2i])
    t2i+=1
   end
  end
  return make_pool(t3)
 end

 local function each(pool,f)
  for v in all(pool.store) do
   if v.alive then
    f(v)
   end
  end
 end

 local function sort_by(pool,sort_value_f)
  pool:each(function(m)
   m._sort_value=sort_value_f(m)
  end)

  -- http://www.lexaloffle.com/bbs/?tid=2477
  local a=pool.store
  for i=1,#a do
   local j = i
   while j > 1 and a[j-1]._sort_value < a[j]._sort_value do
    a[j],a[j-1] = a[j-1],a[j]
    j = j - 1
   end
  end
 end

 return function(store)
  store = store or {}
  local id_counter = 0
  return {
   each = each,
   sort_by = sort_by,
   zip_with = zip_with,
   store = store,
   make = function(obj)
    obj = obj or {}
    obj.alive = true
    local id = false

    for k,v in pairs(store) do
     if not v.alive then
      id = k
     end
    end

    if not id then
     id_counter+= 1
     id = id_counter
    end
    store[id] = obj
    obj.kill = function()
     obj.alive = false
    end
    return obj
   end
  }
 end
end)()

makevec2d = (function()
 mt = {
 __add = function(a, b)
  return makevec2d(
  a.x + b.x,
  a.y + b.y
  )
 end,
 __sub = function(a,b)
  return a+makevec2d(-b.x,-b.y)
 end,
 __mul = function(a, b)
  if type(a) == "number" then
  return makevec2d(b.x * a, b.y * a)
  elseif type(b) == "number" then
  return makevec2d(a.x * b, a.y * b)
  end
  return a.x * b.x + a.y * b.y
 end,
 __div = function(a,b)
  return a*(1/b)
 end,
 __eq = function(a, b)
  return a.x == b.x and a.y == b.y
 end
 }
 local function vec2d_tostring(t)
 return "(" .. t.x .. ", " .. t.y .. ")"
 end
 local function magnitude(t)
 return sqrt(t.x*t.x+t.y*t.y)
 end
 local function bearing(t)
 return makeangle(atan2(t.x,t.y))+.25
 end
 local function diamond_distance(t)
  return abs(t.x)+abs(t.y)
 end
 local function normalize(t)
  return t/t:tomagnitude()
 end
 local function project_onto(t,direction)
  local dir_mag=direction:tomagnitude()
  return ((direction*t)/(dir_mag*dir_mag))*direction
 end
 local function cross_with(t,vector)
  -- signed magnitude of 3d cross product
  return t.x*vector.y-t.y*vector.x
 end
 return function(x, y)
 local t = {
  x=x,
  y=y,
  tostring=vec2d_tostring,
  tobearing=bearing,
  tomagnitude=magnitude,
  diamond_distance=diamond_distance,
  project_onto=project_onto,
  cross_with=cross_with,
  normalize=normalize
 }
 setmetatable(t, mt)
 return t
 end
end)()

makeangle = (function()
 local mt = {
  __add=function(a,b)
   if type(a) == "table" then
    a=a.val
   end
   if type(b) == "table" then
    b=b.val
   end
   local val=a+b

   if val < 0 then
    val = abs(flr(val))+val
   elseif val >= 1 then
    val = val%1
   end
   return makeangle(val)
  end,
  __sub=function(a,b)
   if type(b) == "number" then
    return a+makeangle(-b)
   else
    return a+makeangle(-b.val)
   end
  end
 }
 local function angle_tovector(a)
  return makevec2d(cos(a.val-.25),sin(a.val-.25))
 end
 return function(angle)
  local t={
   val=angle,
   tovector=angle_tovector
  }
  setmetatable(t,mt)
  return t
 end
end)()

function angle_to_screenx(angle)
 local offset_from_center_of_screen = -sin(angle.val-player.bearing.val)
 local screen_width = -sin(field_of_view/2) * 2
 return round(offset_from_center_of_screen/screen_width * 128 + 127/2)
end

function screenx_to_angle(screenx)
 local screen_width = -sin(field_of_view/2) * 2
 local offset_from_center_of_screen = (screenx - 127/2) * screen_width/128
 return makeangle(player.bearing.val+atan2(offset_from_center_of_screen, 1)+1/4)
end
-- end ext

-- start ext ./sprites.p8

cached_sprites={}

aomx = {}
aomy = {}
for ix=1,8 do
 aomx[ix] = {}
 aomy[ix] = {}
 for iy=1,16 do
  aomx[ix][iy] = 0
  aomy[ix][iy] = 0
 end
end

function minn(a,b)
 if a < b then
  return a
 else
  return b
 end
end

is_running_wander=false
function wander_aom()
 if max_screenx_offset == 0 then
  if not is_running_wander then
   return
  else
   for ix=1,8 do
    for iy=1,16 do
     aomx[ix][iy] = 0
     aomy[ix][iy] = 0
    end
   end
   is_running_wander=false
   return
  end
 end
 is_running_wander = true

 if enable_anxiety_x_offset then
  for ix=1,8 do
   for iy=1,16 do
    xw = (rnd()-.5)*max_screenx_offset*.1
    aomx[ix][iy] = mid(-max_screenx_offset,xw + aomx[ix][iy],max_screenx_offset)
   end
  end
 end
 for ix=1,8 do
  for iy=1,16 do
   yw = (rnd()-.5)*max_screenx_offset*.1
   aomy[ix][iy] = mid(-max_screenx_offset,yw + aomy[ix][iy],max_screenx_offset)
  end
 end
end

function is_sprite_wall(sprite_id)
 return sprite_id > 0 and not fget(sprite_id,7) and not fget(sprite_id,6)
end

function is_sprite_wall_transparent(sprite_id)
 return fget(sprite_id,0)
end

function is_sprite_mob(sprite_id)
 return fget(mob_id,7)
end

function is_sprite_skybox(sprite_id)
 return fget(sprite_id,6)
end

function is_sprite_half_height(sprite_id)
 return fget(sprite_id,2)
end

function is_sprite_wall_solid(sprite_id)
 return not fget(sprite_id,3)
end

function is_sprite_door(sprite_id)
 return fget(sprite_id,1)
end

function cache_sprite(sprite_id)
 if not cached_sprites[sprite_id] then
  local pixels_tall=16
  if is_sprite_half_height(sprite_id) then
   pixels_tall=8
  end
  local spritex=8*(sprite_id%16)
  local spritey=8*flr(sprite_id/16)
  cached_sprites[sprite_id]={}
  for cx=1,8 do
   cached_sprites[sprite_id][cx]={}
   for cy=1,pixels_tall do
    cached_sprites[sprite_id][cx][cy]=sget(spritex+cx-1,spritey+cy-1)
   end
  end
 end
end

fisheye_ratio = 0.0
-- this assumes a distance to the screen of 1 since it cancels out anyways
function calc_fisheye_correction(angle)
 local adjusted = (angle.val-player.bearing.val) % 1
 --limit the correction to the edge of the screen
 --otherwise it can make things off screen grow huge and stretch onto the screen
 --this mainly happens with mobs
 -- this check brings performance down (1.7558 -> 1.7706) but I think it's acceptable
 if adjusted < .5 and adjusted > field_of_view/2 then
  adjusted = field_of_view/2
 elseif adjusted >= .5 and adjusted < 1-field_of_view/2 then
  adjusted = 1-field_of_view/2
 end

 local fisheye_coefficient = 1 / sin(3/4+adjusted)
 fisheye_coefficient += (1 - fisheye_coefficient) * fisheye_ratio
 return fisheye_coefficient
end

fog_swirl_offset=0
fog_swirl_limit=10
fog_swirl_tilt=.03
fog_pattern=0
function deferred_fog_draw(angle,distance,draw_width,screenx,bg_only)
 local height=2*calc_fisheye_correction(angle)*height_scale/distance/field_of_view
 local screeny=64+height*height_ratio-height
 local screenxright=screenx+draw_width-1

 return {
  key=-distance,
  draw=function()
   if bg_only then
    rectfill(screenx,screeny,screenxright,screeny+height,0)
   else
    fillp(fog_pattern)
    rectfill(screenx,screeny,screenxright,screeny+height,5)
    fillp()
   end
  end
 }
end

base_pattern = 0b1011010100100101
offset = 0
function update_fog_swirl()
 offset+=.21
 offset=offset%16
 offsetv=flr(offset+player.bearing.val*128/field_of_view)%16
 fog_pattern = shl(base_pattern,offsetv)
 fog_pattern = bor(fog_pattern,band(0b1111111111111111,lshr(base_pattern,16-offsetv)))
 fog_pattern+= 0b0.1
end

function deferred_wall_draw(angle,distance,sprite_id,pixel_col,draw_width,screenx)
 if distance < distance_from_player_cutoff then
  return
 end

 local sprites_tall
 if is_sprite_half_height(sprite_id) then
  sprites_tall = 1
 else
  sprites_tall = 2
 end

 local screenxleft=screenx
 local screenxright=screenx+draw_width-1
 local hit_count=1
 local fisheye_correction=calc_fisheye_correction(angle)

 return {
  key=-distance,
  add_hit=function(obj,new_dist,screenx,draw_width)
   obj.key = (obj.key*hit_count+-new_dist) / (hit_count+1)
   hit_count+=1
   screenxright=screenx+draw_width-1
  end,
  draw=function(obj)
   --sspr sx sy sw sh dx dy [dw dh] [flip_x] [flip_y]
   local sprite_height=fisheye_correction*height_scale/distance/field_of_view
   local bottomy = round(63.5+sprite_height*2*height_ratio)
   local topy = round(63.5-sprite_height*sprites_tall*(sprites_tall/2-height_ratio))
   local height = bottomy-topy

   sspr((sprite_id%16)*8+pixel_col,flr(sprite_id/16)*8,1,sprites_tall*8,screenx,topy,screenxright-screenxleft+1,height)
  end
 }
end

cached_mobs={}
function clear_draw_cache()
 cached_mobs={}
end

function cache_mob(mob,dir_vector,screenx,draw_width)
 local cached_mob=cached_mobs[mob.id]
 if cached_mob then
  return cached_mob
 end
 local color_translate_map = {
  0,1,2,
  2,1,5,6,
  2,4,9,3,
  1,2,2,4
 }

 local mob_bearing=mob.bearing

 local vec_to_mob=mob.coords-player.coords
 local distance=vec_to_mob:tomagnitude()
 local normal_vec_to_mob=vec_to_mob/distance

 if distance < distance_from_player_cutoff then
  cached_mobs[mob.id]={draw=false}
  return cached_mobs[mob.id]
 end

 local width_vector=(mob_bearing-.25):tovector()
 local side_length=(width_vector*normal_vec_to_mob)/8
 local face_length=mob_bearing:tovector()*normal_vec_to_mob

 local side_to_left=side_length*face_length<0

 local angle_to_mob = vec_to_mob:tobearing()

 -- If they're behind us, do not draw.
 -- Due to how mob detection happens, mobs behind the player can sometimes get fed in
 if cos(angle_to_mob.val - player.bearing.val) < 0 then
  cached_mobs[mob.id]={draw=false}
  return cached_mobs[mob.id]
 end

 local height=2*calc_fisheye_correction(angle_to_mob)*height_scale/distance/field_of_view
 local screen_width=abs(face_length)*height/2
 local screen_side=abs(side_length)*height/2

 local screenx_mob=angle_to_screenx(angle_to_mob)
 if side_to_left then
  screenx_mob+=screen_side/2
 else
  screenx_mob-=screen_side/2
 end
 local left_screenx_mob=screenx_mob-screen_width/2
 local screeny=flr(64-height*(1-height_ratio))

 local columns={}
 local column
 for col_i=0,7 do
  column={
   xo=flr(left_screenx_mob+col_i/8*screen_width),
   xf=flr(left_screenx_mob+(col_i+1)/8*screen_width)-1
  }
  add(columns,column)
 end

 local rows={}
 local row,pixel,pixel_color
 local sides, side

 local spritex=8*flr(mob.sprite_id%16)
 local spritey=8*flr(mob.sprite_id/16)

 local total_rows=16
 if is_sprite_half_height(mob.sprite_id) then --hax for half height mobs
  total_rows=8
  spritey-=8
 end

 for row_i=16-total_rows,15 do
  row={
   yo=flr(screeny+row_i/16*height),
   yf=flr(screeny+(row_i+1)/16*height)-1,
   pixels={}
  }
  sides={}
  for col_i=0,7 do
   pixel_color=sget(col_i+spritex,row_i+spritey)
   if pixel_color == 14 then
    if face_length <= 0 then
     pixel_color=7
    else
     pixel_color=15
    end
   end
   if pixel_color > 0 then
    if side_to_left then
     side={
      xo=columns[col_i+1].xo-screen_side,
      xf=columns[col_i+1].xo-1,
      color=color_translate_map[pixel_color]
     }
    else
     side={
      xo=columns[col_i+1].xf+1,
      xf=columns[col_i+1].xf+screen_side,
      color=color_translate_map[pixel_color]
     }
    end
    add(sides,side)
   end
   add(row.pixels,pixel_color)
  end
  row.sides=sides
  add(rows,row)
 end

 local mob_data={
  rows=rows,
  columns=columns,
  side_length=tounit(side_length*face_length)*screen_side,
  distance=distance,
  draw=true
 }

 if screen_width < 1 then -- we can only see the side so skip listing the columns
  mob_data.columns={}
 end

 cached_mobs[mob.id]=mob_data

 return mob_data
end

function deferred_mob_draw(mob,dir_vector,screenx,draw_width)
 local mob_data=cache_mob(mob,dir_vector,screenx,draw_width)

 -- This is a bit hacky... but it's ok for now
 if not mob_data.draw then
  return {
   key=0,
   draw=noop_f
  }
 end

 return {
  key=-mob_data.distance,
  draw=function()
   local pixel,column
   for row in all(mob_data.rows) do
    if mob_data.side_length >= 1 then
     for side in all(row.sides) do
      rectfill(side.xo,row.yo,side.xf,row.yf,side.color)
     end
    elseif mob_data.side_length <= -1 then
     for i=#row.sides,1,-1 do
      side=row.sides[i]
      rectfill(side.xo,row.yo,side.xf,row.yf,side.color)
     end
    end
    for i=1,#mob_data.columns do
     pixel = row.pixels[i]
     column = mob_data.columns[i]
     if pixel > 0 then
      rectfill(column.xo,row.yo,column.xf,row.yf,pixel)
     end
    end
   end
  end
 }
end

makemobile = (function()
 local mob_id_counter=0

 local function turnto(m,target)
  local bearing_diff=((m.coords-target.coords):tobearing()-m.bearing).val-.5
  m.bearing+=mid(-.01,.01,bearing_diff)
  return bearing_diff
 end

 local function talk(m)
  if m.talk_delay <= 0 then
   sfx(flr(rnd(4)))
   m.talk_delay=30+rnd(10)
   add_anxiety()
  else
   m.talk_delay-=1
  end
 end

 local function filter_axis(mob,axis,diff)
  --TODO - the if/else in here suck but it's awkward anyways
  local orig=mob.coords[axis]
  local val=orig+diff
  local filtered=val
  local sprite_id,cross,x,y
  if axis=='x' then
   cross=mob.coords['y']
  else
   cross=mob.coords['x']
  end

  local front_edge = orig+mob.hitbox_radius*tounit(diff)
  local curr_axis = round(front_edge+diff)

  for curr_cross=round(cross-mob.hitbox_radius),round(cross+mob.hitbox_radius) do
   if axis=='x' then
    sprite_id = mget(curr_axis,-curr_cross)
   else
    sprite_id = mget(curr_cross,-curr_axis)
   end
   if is_sprite_wall(sprite_id) and is_sprite_wall_solid(sprite_id) then
    return orig
   end
  end

  return val
 end

 local function apply_movement(mob,movement)
  mob.entering_door=false
  local x,y
  x=filter_axis(mob,'x',movement.x)
  y=filter_axis(mob,'y',movement.y)

  local proposed_tile_id=mget(round(x+tounit(movement.x)*mob.hitbox_radius), -round(y+tounit(movement.y)*mob.hitbox_radius))

  -- workaround for getting stuck on the corner
  if is_sprite_wall(proposed_tile_id) and is_sprite_wall_solid(proposed_tile_id) then
   if abs(movement.x) > abs(movement.y) then
    y=mob.coords.y
   else
    x=mob.coords.x
   end
  end

  mob.coords = makevec2d(x,y)
 end

 local function default_update(mob)
  local m_to_p=mob.coords-player.coords
  local distance=m_to_p:tomagnitude()
  if distance < 4 then
   if abs(mob:turn_towards(player)) < .1 then
    if distance > 2 then
     mob:apply_movement(m_to_p/distance*-.04)
    else
     mob:talk()
    end
   end
  end
 end

 return function(sprite_id,coords,bearing)
  mob_id_counter+=1
  local obj = {
   id=mob_id_counter,
   sprite_id=sprite_id,
   coords=coords,
   bearing=bearing,
   turn_towards=turnto,
   deferred_draw=deferred_mob_draw,
   talk_delay=0,
   talk=talk,
   apply_movement=apply_movement,
   entering_door=false,
   hitbox_radius=mob_hitbox_radius,
   update=default_update
  }
  return obj
 end
end)()

makeitem = (function()
 local function item_update(mob)
  mob.bearing+=.01
  if (player.coords-mob.coords):diamond_distance() < .5 then
   mob:on_pickup()
  end
 end

 return function(sprite_id,coords,bearing)
  local obj=makemobile(sprite_id,coords,bearing)
  obj.update=item_update
  obj.on_pickup=noop_f
  return obj
 end
end)()

makecoin = (function()
 local function pickup(mob)
  mob:kill()
  add_coin()
 end

 return function(sprite_id,coords,bearing)
  local obj=makeitem(sprite_id,coords,bearing)
  obj.on_pickup=pickup
  return obj
 end
end)()

makewhisky = (function()
 local function pickup(mob)
  if coin_count >= 5 then
   mob:kill()
   add_whisky()
  end
 end

 return function(sprite_id,coords,bearing)
  local obj=makeitem(sprite_id,coords,bearing)
  obj.on_pickup=pickup
  return obj
 end
end)()

makeclerk = (function()
 local function clerk_update(mob)
  local m_to_p=mob.coords-player.coords
  local distance=m_to_p:tomagnitude()
  if distance < 2.2 then
   if abs(mob:turn_towards(player)) < .1 then
    mob:talk()
    make_payment()
   end
  end
 end

 return function(sprite_id,coords,bearing)
  local obj=makemobile(sprite_id,coords,bearing)
  obj.update=clerk_update
  return obj
 end
end)()

-- end ext

-- start ext ./main.lua
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

   if distance > draw_distance * .9 and not drawn_fog then
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
   elseif mob_id == 41 then
    mobile_pool.make(makeclerk(mob_id,makevec2d(x,-y),makeangle(rnd())))
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

 update_inventory()

 update_popup()
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

making_payment=false
function make_payment()
 if has_whisky and coin_count > 0 then
  popup("pAYING FOR WHISKY...",20,11)
  making_payment = true
 end
end

paid_for_whisky = false
payment_progress = 0
function update_inventory()
 if making_payment then
  payment_progress+=.005
  if payment_progress >= 1 then
   coin_count = 0
   paid_for_whisky = true
   payment_progress = 0
   popup("whisky purchased!",60,11,true)
  end
 else
  payment_progress = 0
 end
 making_payment = false
end

popup_duration = 0
popup_text = ""
popup_color = 8
popup_blinking = false
function popup(text,duration,colr,blinking)
 popup_duration = duration
 popup_text = text
 popup_color = colr
 popup_blinking = blinking
end

function update_popup()
 if popup_duration > 0 then
  popup_duration-=1
 end
end

--popup border sizes
pb1 = 7
pb2 = 6
pb3 = 4
pb4 = 3
function draw_popup()
 if popup_duration > 0 then
  local textxo = 64-#popup_text*4/2
  local textxf = textxo + #popup_text*4 - 2
  local textyo = 51
  local textyf = 55
  rect(textxo-pb1,textyo-pb1,textxf+pb1,textyf+pb1,ground_color)
  fillp(0b0101101001011010)
  rectfill(textxo-pb2,textyo-pb2,textxf+pb2,textyf+pb2,ground_color*16+sky_color)
  fillp(0)
  rect(textxo-pb3,textyo-pb3,textxf+pb3,textyf+pb3,sky_color)
  rectfill(textxo-pb4,textyo-pb4,textxf+pb4,textyf+pb4,0)
  if not popup_blinking or popup_duration % 10 < 9 then
   print(popup_text,textxo,textyo,popup_color)
  end
 end
end

function draw_inventory()
 if payment_progress > 0 then
  rectfill(83,8,83+ceil(43*payment_progress),15,11)
 end
 for i=1,coin_count do
  spr(17,128-i*9,8)
 end
 if payment_progress > 0 then
  fillp(0b0101101001011010.1)
  rectfill(83,8,83+ceil(43*payment_progress),15,11)
  fillp(0)
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

  draw_popup()
 end

 if debug then
  draw_debug()
 end
end
-- end ext

__gfx__
000000000000000067676767bbbbbbbb900000096767676730030b5030300b5300000000000000000b00b03b30030b500d090e0a777777776666666677777777
000000000000000044444444bbbbbbbb090000904444444433853b3333803b330000000000000000b00b1bb0355555538d0bbe9a746d64675a8da8be76666667
000000000000000049494949bbbbbbbb009999004666666933b334b333b334b3000000000000000031b31131351010538d0bbe9a7dd4d6477777777776777767
000000000000000049494949bbbbbbbb0000000046555569b3335bb4b3330bb40f000f0000000000311b1bb1b501015477777777777777776666666676767767
000000000000000049494949bbbbbbbb00000000465555694b45b3334b45b00349f049f000000000b113113b451010535555559575555557f58abfae76776767
000000000000000049494949bbbbbbbb00000000465555693b354b333b054b0349f049f000800b0a3b1bb131350101535b5ccbd87eecc9977777777776777767
000000000000000049494949bbbbbbbb0000000046555569b33334bbb00004bb49f049f000b0b00b311311bbb510105b5b8ccbec7eecc9976666666676666667
000000006777677749494949bbbbbbbb77777777466666694b55233b4b55200b49f049f0b3bc3bb331b311314501066b7777777777777777feb8eb8a77777777
0000500000aaaa00494949490000000066666666465555693b33b53b3b00b50bffffffff54445444311b1bb13510166b5e555b557332e8877777777776666667
000090000a9999a04949494900000000666666664655596934bb35b434bb05b44444444449494949b113113b35010154ae8c9bee7b5e29976666666676777767
00a999a0a9aaaa9a49494949000000006666666646555569eb45334beb45004b9999999949f949f93113b131e510105bae8c9bee75b2e887b5b2e8be76776767
00999990a9a00a9a4949494900000000660000664655556934b3353b34b0050b4444444447f747f73b1b11bb3501015b77777777777777777777777776767767
00777770a9a00a9a494949490000000040000004465555693b4395b43b4095b412201220ffafffafb11311313510105455a555c57cc66cc77777777776777767
00777770a9aaaa9a494949490000000040000004465555693b533b433b500b4349f049f047f747f731b31bb13501015338a99ac8766cc6677777777776666667
009999900a9999a04444444400000000400000044655556434b553b334b553b349f049f049f949f9311b11313510105338a99ac8777777777777777777777777
0044444000aaaa0012121212000000004000000416666662354b33b5354b33b549f049f049494949311311313555555377777777751515177777777777777777
00000000006660000000000055555555000000000000000067676767111111111111111100000000000000000000000000000000000000000000000000000000
00000a0000666000000000005cccccc5000000000000000044444444111111111111111100060000000000000000000000000000000000000000000000000000
00aaa0000a666a00000000005ccc6cc5000000000000000049494949111111111111111100666000000000000000000000000000000000000000000000000000
00fff00000fff000000000005c6cc6c5000000000110555549494949111111111111111100fff000000000000000000000000000000000000000000000000000
0fefef000fefef00000000005cc6ccc50000000011115bb54949494900000000333333330fefef00000000000000000000000000000000000000000000000000
00fff00000fff0000b0ccb085ccc6cc5000000001111001049494949000000003333333300fff000000000000000000000000000000000000000000000000000
000f0000000f00009b8ccbec5c6cc6c50000000011110010494949490000000033333333000f0000000000000000000000000000000000000000000000000000
0666660006666600777777775cc6ccc5666666666666666649494949000000003333333307878700000000000000000000000000000000000000000000000000
66666660666666605e555b555cccccc5777777767777777649494949777777777777777777878770000000000000000000000000000000000000000000000000
6066606060666060ae8c9bee56666665777777767777777649494949777777777777777770888070000000000000000000000000000000000000000000000000
6066606060666060ae8c9bee55555555777777767777777649494949777777777777777770888070000000000000000000000000000000000000000000000000
6099906060999060777777775cccccc5777777767777777649494949777777777777777770888070000000000000000000000000000000000000000000000000
00ccc0000099990055a555c55c6c6cc5777777767777777649494949222222225555555500555000000000000000000000000000000000000000000000000000
00c0c0000099990038a99ac85cc6c6c5777777767777777649494949222222225555555500505000000000000000000000000000000000000000000000000000
00c0c00000f0f00038a99ac85cccccc5777777767777777644444444222222225555555500505000000000000000000000000000000000000000000000000000
00909000008080007777777755555555777777767777777612121212222222225555555500404000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6010101010101010101010101010101010101010101010101010101010101010f000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6010101010101010101010101010101010101010101010007200101010101010f000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
608080808080808080001000808080808080f0f0f0f0f0f032f0f0f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
600000000000000080001000800000000000f0000000000083000000004200f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
600000000000000080001000800000000000f0000000000000000000004200f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
600070707070700080007200800070707070f0000000000000000000005292f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
202020202020202020205020202020202020f0000022220000222200004200f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
200000000000000000007300200000000020f0000022220000222200005292f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
204000000200000000000000200000000020f0000000000000000000004200f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
204000000000000000000000500000000020f0000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
204000000200000000000000200000000020e0000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
204000000000000200000000202050202020e012c000c000c000c000c000c0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
204000000000000000000000000000000020e000c000c000c000c000d000d0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
200000000200730000020000000073000020e000c012c000c000c000d000d0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
202020202020502020202020202050202020e000c000c000c002c000d000d0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
607070707070b070700000000070b0701260e000c000c000c000c002d000d0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
600000000000820000000000007082700060e000c000c012c000c000c000c0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
600012000000000000000000000000000060e0000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
606060606060000000000000006000600260e0000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000000060001200000000000000001260e0002222220000220000222222f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000000060000000020000000060606060e0000000000000000000120000f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000008080800000000000000000800000a0e0000000000000000200000000f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a090008000000000000000000000800090a0e000c000c000c000c000c000c0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000008000000000909090900000800000a0e002c000c000c000c000c000c0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000008000000000000000000000800000a0e000c000c000c000c000c000c0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a090008012020000000000000000800090a0e000c000c000c000c000c000c0f00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000008080808080808080808080800000a0e000c002c000c000c000c000c0f0f0f0f0f000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000000000000000000000000000000a0e000c000c000c000c000c000c0f0000000f000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a090000090000090000090000090000090a0e000000000000000000000000000000100f000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0e000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e0e0e0f0f0f0f0f000000000000000000000000000000000000000000000000000000000
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111b553333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111bb553333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111bb553333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111bb533333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111bb533333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131bb333333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131bb333333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131bb333333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131bb333333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131bb333333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131bb333333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131bb333333333bb
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bb333333333b3
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131133bb33333333333
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131153bb3b333333333
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131153bb3b333333333
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131853bbbb333333333
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131853bbbb333333333
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131853b4bb333333333
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111115133853b4bb333b33333
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111513385344bb333b33333
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111513385344bb33bb33333
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111513385344bb34bb33333
311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111533383344bb34bb33333
331111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111533383344bb44bb33333
3311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111115333b3344bb44bb33333
3311111131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113333b3344bb44bb33333
3311111133311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113113333b3344bb44bb33334
3311111133311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113133333b3344bb44bb33344
33111111333111bb111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113133333b334bbb44bb33b44
33311111333111bb551111111111111111111111111111111111111111111111111111111111111111111111111111111111111113133333b33bbbb44bb3bb44
33333811333111bb555111111111111111111111111111111111111111111111111111111111111111111111111111111111111113833333b35bbbb44bbbbb44
33333888533111bb555111111111111111111111111111111111111111111111111111111111111111111111111111111111111113833333b35bbbb44b4bbb44
33333888555311bb55511111111111111111111111111111111111111111111111111111111111111111111111111111111111111383b333b35bbbb4444bbb44
33333888555333bb55511111111111111111111111111111111111111111111111111111111111111111111111111111111111111383b333335bbbb4344bbb44
33333888555333bb33511111111111111111111111111111111111111111111111111111111111111111111111111111111111111383b333335bbbb3344bbb44
33333888555333bb33333111111111111111111111111111111111111111111111111111111111111111111111111111111111111383b333335bbbb3344bbb44
33333b88555333bb333331111111111111111111111111111111111111111111111111111111111111111111111111111111111113b3b3b3335bbb33344bbb44
33333bbb335333bb333331111111111111111111111111111111111111111111111111111111111111111111111111111111111113b3b4b3335bb333344bbb44
33333bbb333333bb333331111111111111111111111111111111111111111111111111111111111111111111111111111111111113b3b4b3335b3333344bbb44
33333bbb33333344b33331111111111111111111111111111111111111111111111111111111111111111111111111111111111113b3b4b333b33333344bbb44
33333bbb33333344bbb331111111111111111111111111111111111111111111111111111111111111111111111111111111111113b5b4b333b33333344bbb44
bb333bbb33333344bbb3311111111111111111111111111111111111111111111111111111111111111111111aaaa9111111111113b5b4b335b33333344bbb43
bb33333b33333344bbb3311111111111111111111111111111111111111111111111111111111111111111111aaaa911111111111335b4b345b33333344bbb33
bb33333333353344bbb3311111111111111111111111111111111111111111111111111111111111111111111aaaa911111111111b35b4bb45b33333344bbb33
bb333333333555bbbbb3311111111111111111111111111111111111111111111111111111111111111111111aaaa911111111111b35b44b45b33333343bbb33
bb333333333555bbbbb44111111111111111111111111111111111111111111111111111111111aaaaaaaaaaa9111111111111111b35b34b45b33333333bbb33
bb333333333555bbbbb44111111111111111111111111111111111111111111111111111111111aaaaaaaaaaa9111111111111111b35334b45b33333333bbb33
4b333333333555bbbbb44111111111111111111111111111111111111111111111111111111111aaaaaaaaaaa9111111111111111b3b334b45b33333333bbb33
44bbb444333555bbbbb44111111111111111111111111111111111111111111111111111111111aaaaaaaaaaa9111111111111111b4b334b45b3b333333bbb33
44bbb444555bbbbbbbb44111111111111111111111111111111111111111111111111111111111fffffffffff411111111111111144b334b454bb333333bbb33
44bbb444555bbb3333333111111111111111111111111111111111111111111111111111111111fffffffffff411111111111111f44b334b354bb333333bbb33
44bbb444555bbb3333333111111111111111111111111111111111111111111111111111111111fffffffffff4b1133bb1111111f44b334b354bb333333bbb33
44bbb444555bbb3333333111111111111111111111111111111111111111111111111111111111fffffffffff4b1133bb1111141f44b333b354bb333333bbb33
44bbb444555bbb333333311111111111111111111111111111111111111111111111111111ffff7777fff7777ffff4b111111141f444333b354bb333333bbb33
33bbb333555bbb333333311111111111111111111111111111111111111111111111111111ffff7777fff7777ffff4b111111141f434333b354bb333333bbb33
33bbb333555444bb3333311111111ff111111ff111111ff1111111ff11111f1ff1111111ffffff7777fff7777ffff4311f11ff41f334333b354bb333333bbb33
33bbb333555444bb3333311111111ff111111ff111111ff1111111ff11111f1ff1111111ffffff7777fff7777ffff4311f11ff41f334333b354bb333333bbb33
33bbb333555444bb333331111114499ff114499ff114499fff114499fff114499fff1144999ff1fffffffffff4499fff1944994ff334333b354bb3333bb33333
33bbb333555444bb333331881188899ff11bbb9ffaaaa98ffb1a4499fff114499fff1144999ff1fffffffffff4499fffb944994ff334333b354b4bbbbbb33333
33bbb333555444bb3333318811888a9ff11bbb9ffaaaa98ffb1a4499fff114499fff1144999ff1fffffffffff4499fffb944994ff33433b333344bbbbbb33333
bb33333333333344bbbbb18811888a9ff11bbb9ffaaaa98ffb1a4499fff114499fff1144999ffbfffffffffff4499fff1944994ffb33bbb333344bbbbbb33333
bb33333333333344bbbbb1bb1bbbbb9fbbb4499ffbbbb9bfbf1b4499fff114499fff1144999ffb1444fff411b4499fff1944994ffb33bbb333344bbbbbb33333
bb33333333333344bbbbb1bb1bbbbb9fbbb4499ffbbbb9bfbf1b4499fff114499fff1144999ff11444fff41134499fffb944994ffb33bbb333344bbbbbb33333
bb33333333333344bbbbb1bb1bbbbb9fbbb4499ffbbbb9bfbf1b4499fff114499fff1144999ff11444fff41134499fffb944994ffb33bbb333344bbbbbb33333
bb33333333333344bbbbbbb333bbbccc33b4499ffbbbb9bc3bb34499fff114499fffb344999ffbb444fff4bb34499fff1944994ffb33bbb333344bbbbbb33333
bb33333333333344bbbbbbb333bbbccc333bbbbbb3333bbc3bb34499fff114499fff54449966666666666666666665ff1944994ffb33bbb333344bbbbbb33333
44bbb55555522233333bbbb333bbbccc333bbbbbb3333bbc3bb3ffffffffffffffffffffff66666666666666666665ffffffff4ff452bbb333344bbbbbb33333
44bbb55555522233333bbbb333bbbccc333bbbbbb3333bbc3444ffffffffffffffffffffff66666666666666666665ffffffff4ff4523b4b33344bbbbbb33333
44bbb55555522233333bb5544444444455544444444445445444444444444444444444444466666666666666666665ffffffff4ff4523b4b55234bbbbbb33333
44bbb55555522233333bb554444444445554444444444544544444444444444444444466666666666666666666666666654444f4f4523b4b5523333bbbb33333
44bbb55555522233333bb554444444445554444444444544594944444444444444444466666666666666666666666666654444fff4523b4b5523333bb4433333
44bbb555555bbb55333bb449994449994449994449999449494999999999999999999966666666666666666666666666659999fff4523b4b5523333bb44bbb53
43bbb333333bbb55333bb449994449994449994449999449494999999999999999999966666666666666666666666666659999fff3323b4b5523333bb44bbb55
33bbb333333bbb55333bb44999444999444999444999944949f944444444444444444466665444666666666665444666654444fff33b3b4b5523333bb44bbb55
33bbb333333bbb55333bb44999fff99944499944499994f949f9444444444444444444666654446666666666654446666544444ff33b3b4b5523333bb44bbb55
33bbb333333bbb55333bb44999fff999444999fff99994f949f91122222111122222476666522766666666666544466665412244f33b3b3b5523333bb44bbb55
33bbb333333bbb55bbb4444999fff999444999fff99994f949f71122222111122222476666522766666666666512266665112244433b3b3b3523333bb44bbb55
33bbb3333bb33355bbb4444779fff999444999fff99994f747f74499fff111122222496666522966666666666512266665112244433b3b3b3323333bb44bbb55
33b44bbbbbb33355bbb4444777fff777444777fff77774f747f74499fff114499fff4966665ff96666666666654996666544999443bb3b3b33b5333bb44bbb55
33444bbbbbb33355bbb4444777fff777444777fff77774f747af4499fff334499fff4966665ff96666666666654996666544999443b33b3b33b5533bb44bbb55
33444bbbbbb33355bbb4444777fff777444777fff77774ffffaf4499fff334499fff3366665ff96666666666654996666544999943b33b3b33b5533bb44bbb55
33444bbbbbb33355444bbfffffaaafffffffffaaaf777fafffaf4499fff334499fff3366665ff39999999999944996666544999993b3bb3b33b5533bb44bbb55
33444bbbbbb33333444bbfffffaaafffffffffaaafffffaffff74499fff334499fff3366665ff39999999999944996666544994993b3b43b33b5533bb44bbb55
33444bbb55533333444bbfffffaaafffffffffaaafffffaf47f74499fff334499fff3366665ff3999999999994499666654499499eb3b43b33b5533bb33bbb55
334bb44455533333444bb44777fff77744ffffaaaffffff747f733333333333333ff3366665ff3999999999994499666654499449e43b43433b5533bb33bbb55
eebbb44455533333444bb44777fff777444777fff77774f747f933333333333333333333333333ccccccccccc1333333333333449e43b434b3b5533bb33bbb55
eebbb44455533333433bb44777fff777444777fff77774f749f933333333333333333333333333ccccccccccc1333333333333444e43b434bbb5533bb33bbb35
eebbb44455533355333bb44999fff777444777fff77774f949f933333333333333333333333333ccccccccccc1333333333333144e43b434bb35533bb33bbb33
eebbb44455533355333bb44999fff999444999fff99994f9494933333333333333333333333333ccccccccccc13333333333331443434434bb35533bb33bbb33
eebbb44b33333355333bb44999fff999444999fff99994f9494933333333333333333333333333cccc133cccc13333333333331343434b34bb35533bb33bbb33
eebb4bbb33333355333bb44999fff999444999fff99994f9494933333333333333333333333333cccc133cccc13333333333331343b34b34bb355b3bb33bbb33
33444bbb3333335533b44449994449994449994ff9999449493333333333333333333333333333cccc133cccc13333333333334343b34be4bb355b3bb33bbb33
33444bbb33333355bbb44449994449994449994449999449433333333333333333333333333333cccc133cccc13333333333334323b34bebbb355bbbb33bbb33
33444bbb33339955bbb44349994449994449994449999443333333333333333333333333333333cccc133cccc13333333333334323b34bebbb355bb4b33bbb33
33444bbb33399955bbb44333333333333349994449999433333333333333333333333333333333cccc133cccc13333333333334323b34beb4b355bb4433bbb33
33444bb433399955bbb44333333333333333333333333333333333333333333333333333333333cccc133cccc13333333333334323b33beb45355bb4433bbb33
3344b44433399955bb433333333333333333333333333333333333333333333333333333333333cccc133cccc13333333333334323b33beb45355bb4433bbb33
33bbb444333999554443333333333333333333333333333333333333333333333333333333333399994339999433333333333343f3433beb45355bb44334bb33
33bbb444333999bb4443333333333333333333333333333333333333333333333333333333333399994339999433333333333343f3433beb45335bb44334bb33
33bbb444333333bb4443333333333333333333333333333333333333333333333333333333333399994339999433333333333343f3493b3b45335bb443344b33
33bbb444333333bb4443333333333333333333333333333333333333333333333333333333333399994339999433333333333343f3493b3b45333bb443344433
33bbb455333333bb4443333333333333333333333333333333333333333333333333333333333333333333333333333333333343f3493b34453334b4433444b3
33bbb555333333bb4bb3333333333333333333333333333333333333333333333333333333333333333333333333333333333343f349bb34453334b4433444bb
33bbb555333333b3bbb3333333333333333333333333333333333333333333333333333333333333333333333333333333333343f359bb34b5333444433444bb
33bbb55533333533bbb3333333333333333333333333333333333333333333333333333333333333333333333333333333333333f359b434b5333444433444bb
33bbb55533355533bbb3333333333333333333333333333333333333333333333333333333333333333333333333333333333333f359b434b333344b433444bb
33bbb55555555533bbb5533333333333333333333333333333333333333333333333333333333333333333333333333333333333f353b434b333344bb33444bb
33bbb5bb55555533bbb5533333333333333333333333333333333333333333333333333333333333333333333333333333333333f353b434b335344bb33444bb
33bb4bbb55555533bbb5533333333333333333333333333333333333333333333333333333333333333333333333333333333333f3534434b335344bbe3444bb
33444bbb55555533bbb5533333333333333333333333333333333333333333333333333333333333333333333333333333333333f3b3443bb335344bbee444bb
33444bbb55553333bbb5533333333333333333333333333333333333333333333333333333333333333333333333333333333333f3b3443bb335544bbee444bb
33444bbb55b33333bbb3333333333333333333333333333333333333333333333333333333333333333333333333333333333333f3b3433b4335544bbeeb44bb
33444bbbbbb33333bb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333f3b5433b4335534bbeeb44bb
33444b44bbb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b5433b4335534bbeebb4bb
33445444bbb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b5433b4335533bbeebbbbb
33555444bbb3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333345b33b4335533bbeebbbbb
33555444bbb3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333345b33b4395533bbeebbb4b
33555444b333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333345b33b4395533bbeebbb44
335554443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333345b33b4395533bbeebbb44
335554333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333343b33b4395533bbeebbb44
335533333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333343b33b5395533bb3ebbb44
335333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b33b5395533bb3ebbb44
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b33b5395533bb33bbb44
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b33b53955b3bb33bbb44
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b33b53955b3bb334bb44
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b33453955bbbb334bb44
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b53453355bbbb334bb44

__gff__
000d0000010a00010101000b01000000848400000000000000000000000000008080010a0101004040800000000000000000000080800040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0606060606060606060606060606060606060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060006000600060006000600060006000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060006000600060006000600060006000f0f0f0f0f0f0f0f0f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000000000000000000000000f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060006000600060006000600060006000f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000000000000000000000000f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060006000600060606060606060606000f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000062000000000000006000f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0606060606060606060000000000060006060f000c000c000c000c000d000d0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000062000000000060000000f000c000c000c000c000d000d0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060606060600060000000000060606000f000c000c000c000c000d000d0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600061100000600060011000000060000000f000c000c000c000c000d000d0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060706000600060707070606060000000f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060006000600060000000600062100110f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060006000600060006060600060000000f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060000000600060000000600060000000f0022222200002200002222220f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600060606000600060606000606060006070f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000006000000000006000000000006000f0000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0606060006060607060006060600060606000f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000700060000000000000000000f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000700060606000606060606060f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000600000000000600000000000f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600001100000606060606000600060606000f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0621210000000600000000000600070000000f000c000c000c000c000c000c0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600002100000600060706060600060000210f0000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000600000000000000071100000f0000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0606060607070606060006060606060606060f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06010101010101010101010101010101010101010101010101010101010101010f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06010101010101010101010101010101010101010101010101010101010101010f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000300000913109131091310a1310e141111511414119141201412115121161171710d1710d1710d1710f1710f17115171181611c151211512216122171171710d1710c1710c1710c1710c171001010010100101
00040000111110d1210a1510a1510a1410a1010c1010f101191111b1411d1711e1712110120101181010110100101001010010100101001010010100101001010010100101001010010100101001010010100101
010300000e1310e1510e1710e17114101131011a1010c1510b15109131081210e1010010100101001010010100101001010010100101001010010100101001010010100101001010010100101001010010100101
000500000f1510f151101511015113101111511d1511e1511e1511f1012115121151211512010120151201512015117101161510e1510c1510c1510c151000010000100001000010000100001000010000100001
__music__
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

