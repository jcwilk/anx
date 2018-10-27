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

makedelays = function(max_ticks)
 local delay_store_size = max_ticks + 1
 local tick_index = 1
 local delay_store = {}
 for i=1,delay_store_size do
  delay_store[i] = {}
 end

 local function process()
  tick_index+= 1
  if tick_index > delay_store_size then
   tick_index = 1
  end
  for fn in all(delay_store[tick_index]) do
   fn()
   --printh(tick_index)
  end
  delay_store[tick_index] = {}
 end

 local function make(fn, delay)
  delay = mid(1,flr(delay),max_ticks)
  local delay_to_index = (tick_index + delay) % delay_store_size
  --printh(delay_to_index)
  add(delay_store[delay_to_index], fn)
 end

 return {
  process = process,
  make = make
 }
end

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

function mapget(x,y)
 if y >= 32 then
  x+= 64
  y-= 32
 end
 return mget(x,y)
end
-- end ext

-- start ext ./sprites.p8
debug_marker_id = 45
cached_sprites={}
freeze_mobs=false

function minn(a,b)
 if a < b then
  return a
 else
  return b
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

function is_sprite_lodge_door(sprite_id)
 return sprite_id == 5 --sprite id of the lodge door
end

function is_sprite_home_door(sprite_id)
 return sprite_id == 64 --sprite id of the home door
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

function reset_anxiety_offsets()
 offsetsx = {
  {0,0,0,0},
  {0,0,0,0},
  {0,0,0,0},
  {0,0,0,0}
 }

 offsetsy = {
  {0,0,0,0},
  {0,0,0,0},
  {0,0,0,0},
  {0,0,0,0}
 }
end

reset_anxiety_offsets()

verticaloffsets = {0,0,0,0,0,0,0,0}
zoffsets = {0,0,0,0,0,0,0,0}
anxiety_vertical_offsets_scalar = 0

function update_panic_offsets()
 local clamp_scale = 20
 local vertical_clamp_scale = 5 --the extra vertical-only offset that always gets added
 local z_clamp_scale = .5
 if is_panic_attack then
  for x=1,4 do
   for y=1,4 do
    offsetsx[x][y] += (rnd()-.5)*2--/2
    offsetsy[x][y] += (rnd()-.5)*2--/2
    offsetsx[x][y] = mid(-anxiety_recover_cooldown*clamp_scale, offsetsx[x][y], anxiety_recover_cooldown*clamp_scale)
    offsetsy[x][y] = mid(-anxiety_recover_cooldown*clamp_scale, offsetsy[x][y], anxiety_recover_cooldown*clamp_scale)
   end
  end
 end
 for x=1,8 do
  verticaloffsets[x] += (rnd()-.5)
  verticaloffsets[x] = mid(-vertical_clamp_scale*anxiety_vertical_offsets_scalar,verticaloffsets[x],vertical_clamp_scale*anxiety_vertical_offsets_scalar)
 end
 for x=1,8 do
  zoffsets[x] += (rnd()-.5)/2
  zoffsets[x] = mid(0,zoffsets[x],z_clamp_scale*anxiety_vertical_offsets_scalar)
 end
end

function deferred_wall_draw(angle,distance,sprite_id,pixel_col,draw_width,screenx)
 if distance < distance_from_player_cutoff then
  return
 end

 local new_distance = distance - zoffsets[pixel_col+1]
 local new_distance_ratio = new_distance / distance
 distance = new_distance
 local extra_overlap = draw_width * (1 / new_distance_ratio - 1) / 2

 local sprites_tall
 if is_sprite_half_height(sprite_id) then
  sprites_tall = 1
 else
  sprites_tall = 2
 end

 local screenxleft=screenx
 local screenxright=screenxleft+draw_width-1
 local hit_count=1
 local fisheye_correction=calc_fisheye_correction(angle)

 local obj = {
  key=-distance,
  add_hit=function(obj,new_dist,newscreenx,draw_width)
   obj.key = (obj.key*hit_count+-new_dist) / (hit_count+1)
   hit_count+=1
   screenxright=newscreenx+draw_width-1
  end
 }
 local verticaloffset = verticaloffsets[pixel_col+1]
 if is_panic_attack then
  obj.draw=function(obj)
   screenxleft -= extra_overlap
   screenxright += extra_overlap

   --sspr sx sy sw sh dx dy [dw dh] [flip_x] [flip_y]
   local sprite_height=fisheye_correction*height_scale/distance/field_of_view
   -- local topy = 63.5-sprite_height*sprites_tall*(2/2-height_ratio) --TODO - this is off for half height sprites, why?
   -- local pixel_height = sprite_height/8
   local pixels_tall = sprites_tall*8

   local bottomy = round(63.5+sprite_height*2*height_ratio)
   local topy = round(63.5-sprite_height*sprites_tall*(sprites_tall/2-height_ratio))
   local height = bottomy-topy
   local pixel_height = height/sprites_tall/8

   local thisxleft, thisxright, thisytop, thisybottom, offsetx, offsety
   for i=0,pixels_tall-1 do

    colr=sget((sprite_id%16)*8+pixel_col,flr(sprite_id/16)*8+i)
    if colr > 0 then
     thisxleft = screenxleft
     thisxright = screenxright
     thisytop = topy+i*pixel_height
     thisybottom = ceil(topy+(i+1)*pixel_height)

     --test offsets
     offsetx = offsetsx[pixel_col % 4 + 1][i % 4 + 1]
     offsety = offsetsy[pixel_col % 4 + 1][i % 4 + 1] + verticaloffset
     thisxleft += offsetx
     thisxright += offsetx
     thisybottom += offsety
     thisytop += offsety
     --endtest

     rectfill(thisxleft,thisytop,thisxright,thisybottom,colr)
    end
   end
  end
 else
  obj.draw=function(obj)
   local width = (screenxright - screenxleft + 1) + round(extra_overlap*2)
   screenxleft -= round(extra_overlap)


   --sspr sx sy sw sh dx dy [dw dh] [flip_x] [flip_y]
   local sprite_height=fisheye_correction*height_scale/distance/field_of_view
   local bottomy = round(63.5+sprite_height*2*height_ratio + verticaloffset)
   local topy = round(63.5-sprite_height*sprites_tall*(sprites_tall/2-height_ratio) + verticaloffset)
   local height = bottomy-topy

   sspr((sprite_id%16)*8+pixel_col,flr(sprite_id/16)*8,1,sprites_tall*8,screenxleft,topy,width,height)
  end
 end

 return obj
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
 local side_length=(width_vector*normal_vec_to_mob)/8 --perceived length of side in meters
 local face_length=mob_bearing:tovector()*normal_vec_to_mob --perceived length of face in meters

 local side_to_left=side_length*face_length<0 --is the side of the mob going to be drawn to the left of the face?

 local angle_to_mob = vec_to_mob:tobearing()

 -- If they're behind us, do not draw.
 -- Due to how mob detection happens, mobs behind the player can sometimes get fed in
 if cos(angle_to_mob.val - player.bearing.val) < 0 then
  cached_mobs[mob.id]={draw=false}
  return cached_mobs[mob.id]
 end

 local height=2*calc_fisheye_correction(angle_to_mob)*height_scale/distance/field_of_view

 --expand
 local screen_width=abs(face_length)*height/2
 local screen_side=abs(side_length)*height/2

 local screenx_mob=angle_to_screenx(angle_to_mob) --the center of the mob in screen coords

 --the x,y of the mob is the center of the mob, so offset the face slightly depending on where the side is
 if side_to_left then
  screenx_mob+=screen_side/2
 else
  screenx_mob-=screen_side/2
 end

 local left_screenx_mob=screenx_mob-screen_width/2 --the left edge of the face in screen coords
 local screeny=flr(64-height*(1-height_ratio)) --the top edge of mob in screen coords

 local columns={}
 local column, xo, xf
 for col_i=0,7 do
  xo=left_screenx_mob+col_i/8*screen_width
  xf=left_screenx_mob+(col_i+1)/8*screen_width-1
  column={
   xo=xo,
   xf=max(xo,xf),
   offset=verticaloffsets[col_i+1]
  }
  add(columns,column)
 end

 local rows={}
 local row,pixel,pixel_color
 local sides, side

 local spritex=8*(mob.sprite_id%16)
 local spritey=8*flr(mob.sprite_id/16)

 local total_rows=16
 local vertical_offset
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
   vertical_offset=verticaloffsets[col_i+1]

   if mob.sprite_id == debug_marker_id and pixel_color > 0 then
    pixel_color = mob.overwrite_color
   else
    if pixel_color == 14 then
     if face_length <= 0 then
      if is_panic_attack then
       pixel_color=8 --red
      else
       pixel_color=7
      end
     else
      if is_panic_attack then
       pixel_color=1
      else
       pixel_color=15
      end
     end
    elseif pixel_color > 0 and is_panic_attack then
     pixel_color=1
    end
   end

   if pixel_color > 0 and screen_side >= 1 then
    if side_to_left then
     side={
      xo=columns[col_i+1].xo-screen_side,
      xf=columns[col_i+1].xo-1,
      color=color_translate_map[pixel_color],
      offset=vertical_offset
     }
    else
     side={
      xo=columns[col_i+1].xf+1,
      xf=columns[col_i+1].xf+screen_side,
      color=color_translate_map[pixel_color],
      offset=vertical_offset
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

   --Draw the sides of the figures first since the sides will always be behind the faces
   for row in all(mob_data.rows) do
    if mob_data.side_length >= 1 then
     for side in all(row.sides) do
      rectfill(side.xo,row.yo+side.offset,side.xf,row.yf+side.offset,side.color)
     end
    elseif mob_data.side_length <= -1 then
     for i=#row.sides,1,-1 do
      side=row.sides[i]
      rectfill(side.xo,row.yo+side.offset,side.xf,row.yf+side.offset,side.color)
     end
    end
   end

   --Draw the face of the figures last so that they're always on top
   for row in all(mob_data.rows) do
    for i=1,#mob_data.columns do
     column = mob_data.columns[i]
     pixel = row.pixels[i]
     if pixel > 0 then
      rectfill(column.xo,row.yo+column.offset,column.xf,row.yf+column.offset,pixel)
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
  m.bearing+=mid(-.02,.02,bearing_diff)
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
    sprite_id = mapget(curr_axis,-curr_cross)
   else
    sprite_id = mapget(curr_cross,-curr_axis)
   end
   if is_sprite_wall(sprite_id) and is_sprite_wall_solid(sprite_id) then
    return orig
   end

   if is_sprite_door(sprite_id) and not mob.can_enter_doors then
    return orig
   end

   if is_sprite_door(sprite_id) and has_unpaid_whisky() then
    fail_steal_whisky()
    return orig
   end

   if is_sprite_lodge_door(sprite_id) and not has_whisky then
    fail_enter_lodge()
    return orig
   end

   if is_sprite_home_door(sprite_id) and not has_key then
    fail_go_home()
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

  local proposed_tile_id=mapget(round(x+tounit(movement.x)*mob.hitbox_radius), -round(y+tounit(movement.y)*mob.hitbox_radius))

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

    --if this is exactly 2 then the wiggle room between 1 spaced blocks permits them to get in range
    if distance > 1.8 then
     mob:apply_movement(m_to_p/distance*-.04)
    else
     mob:talk()
    end
   end
  end
 end

 local function is_other_mob(mob,x,y)
  if mob_round_map[x] and mob_round_map[x][y] then
   for mindex=1,#mob_round_map[x][y] do
    if mob_round_map[x][y][mindex].id != mob.id then
     return true
    end
   end
  end
  return false
 end

 local function check_can_pass(mob,x,y)
  return (not is_other_mob(mob,x,y)) and (( not is_sprite_wall(mapget(x,-y))) or (not is_sprite_wall_solid(mapget(x,-y)) ))
 end

 local function reset_mob_path(mob)
  --(sx,sy,fx,fy,max_length,check_can_pass)
  mob.path = find_path(round(mob.coords.x), round(mob.coords.y), round(player.coords.x), round(player.coords.y),8,function(x,y)
   return check_can_pass(mob,x,y)
  end)
  mob.path_index = 1
  --debugmob = mob
  -- printh("PATH size "..#mob.path)
  -- for v in all(mob.path) do
  --   printh("x"..v[1])
  --   printh("y"..v[2])
  --   printh("------")
  -- end
  return mob.path and #mob.path > 0
 end

 local function get_next_coords(mob,offset)
  offset = offset or 0
  if mob:is_on_path(offset) then
   local next_path = mob.path[mob.path_index]
   if next_path then
    return makevec2d(next_path[1],next_path[2])
   end
  end

  return false
 end

 local function follow_path(mob)
  if freeze_mobs then
   return
  end

  local m_to_p=mob.coords-player.coords
  local distance=m_to_p:tomagnitude()

  if not mob.is_pathfinding then
   --printh("waiting"..mob.id)
  end

  if (not mob.path or mob.path_index > #mob.path) and distance < 4 and mob.is_pathfinding then
   if not reset_mob_path(mob) then
    mob.is_pathfinding = false
    local deferred = function()
     mob.is_pathfinding = true
    end
    delays.make(deferred, rnd(30)+30) --try again not before 1-2 seconds have passed
   -- else
   --   reset_mob_position_maps()
   end
  end



  local next_coords = mob:next_coords()

  local is_turning = false

  if distance < 1.80 or (distance < 2.8 and next_coords) then
   is_turning = true

   if abs(mob:turn_towards(player)) < .1 then
    mob:talk()
   end
  end

  if next_coords and distance > 1 then
   if (mob.coords-next_coords):tomagnitude() < .05 then
    if distance < 4 then
     mob:reset_path()
     --reset_mob_position_maps()
    end
    mob.path_index += 1 --skip 1 even if we reset because the first spot is where we already are
    next_coords = mob:next_coords()

    -- if next_coords and mob.path_index > 2 and is_other_mob(mob,next_coords.x,next_coords.y) then
    --   blah()
    --   --mob.path = false
    --   mob:reset_path()
    --   --mob.path_index += 1
    --   return
    -- end
   end

   if next_coords then
    --if abs(mob:turn_towards( {coords=next_coords} )) < .1 then
    mob:apply_movement((mob.coords-next_coords):normalize()*-.08)

    if not is_turning then
     mob:turn_towards( {coords=next_coords} )
    end
   end
  end
 end

 local function reset_position(mob)
  mob.coords = mob.orig_coords
  mob.bearing = mob.orig_bearing
  mob.path = false
 end

 local function is_on_path(mob, offset)
  offset = offset or 0
  return mob.path and mob.path_index and mob.path_index + offset <= #mob.path
 end

 return function(sprite_id,coords,bearing)
  mob_id_counter+=1
  local obj = {
   orig_coords=coords,
   orig_bearing=bearing,
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
   reset_position=reset_position,
   is_pathfinding=true,
   reset_path=reset_mob_path,
   next_coords=next_coords,
   is_on_path=is_on_path,
   next_coords=get_next_coords,
   update=follow_path--default_update
  }
  return obj
 end
end)()

makeplayer = (function()
 return function(sprite_id,coords,bearing)
  local obj=makemobile(sprite_id,coords,bearing)
  obj.can_enter_doors=true
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
  else
   fail_whisky()
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

makepathdebug = (function()
 local function debug_reset_path(mob)
  mob:_reset_path()
  for mindex=1,#mob.markers do
   mob.markers[mindex].kill()
  end
  mob.markers = {}

  local temp
  for cindex=1,#mob.path do
   temp = makeitem( debug_marker_id,makevec2d(mob.path[cindex][1],mob.path[cindex][2]),makeangle(0) )
   temp.overwrite_color = (mob.id % 15) + 1
   mobile_pool.make(temp)
   add(mob.markers,temp)
  end
 end

 return function(sprite_id,coords,bearing)
  local obj=makemobile(sprite_id,coords,bearing)
  obj._reset_path = obj.reset_path
  obj.reset_path = debug_reset_path
  obj.markers = make_pool()
  return obj
 end
end)()

function makekey(sprite_id,coords,bearing)
 local obj = makecoin(sprite_id, coords, bearing)
 obj.on_pickup = function(mob)
  mob:kill()
  add_key()
 end
 return obj
end

function make_sprite_by_id(mob_id, x, y)
 if mob_id == 17 then
  return makecoin(mob_id,makevec2d(x,y),makeangle(rnd()))
 elseif mob_id == 16 then
  return makewhisky(mob_id,makevec2d(x,y),makeangle(rnd()))
 elseif mob_id == 41 then
  return makeclerk(mob_id,makevec2d(x,y),makeangle(rnd()))
 elseif mob_id == 46 then
  return makepathdebug(mob_id,makevec2d(x,y),makeangle(rnd()))
 elseif mob_id == 65 then
  return makekey(mob_id,makevec2d(x,y),makeangle(rnd()))
 else
  return makemobile(mob_id,makevec2d(x,y),makeangle(rnd()))
 end
end

-- end ext

-- start ext ./pathfinding.p8

add_spot = function(obj, old_spot, newx, newy, added_distance)
 local distance_so_far = old_spot.distance_so_far + added_distance

 --skip adding the spot if the spot has already been added by another path which was at least as direct
 --.001 as a float rounding error catchall
 if obj.visited[newx] then
  if obj.visited[newx][newy] and obj.visited[newx][newy] < distance_so_far + .001 then
   return false --skip it, we've seen it
  end
 else
  obj.visited[newx] = {}
 end
 obj.visited[newx][newy] = distance_so_far

 -- if not obj.check_can_pass(newx,newy) then
 --   return false --skip it, it's a wall
 -- end
 if newx == obj.fx and newy == obj.fy then
  return true --we found the target!
 end
 if obj.max_length and obj.max_length <= #old_spot.path then
  return false
 end

 -- shallow copy the previous path into a new path and append the new coords to the end
 local new_path = {}
 for sindex = 1,#old_spot.path do
  add(new_path,old_spot.path[sindex])
 end
 add(new_path,{newx,newy})

 --local distance = distance_so_far + sqrt((newx - obj.fx)^2 + (newy - obj.fy)^2)
 local distance = distance_so_far + abs(newx - obj.fx) + abs(newy - obj.fy)
 local insert_index = 1

 while insert_index <= #obj.spot_q and distance <= obj.spot_q[insert_index].distance  do
  insert_index+= 1
 end

 local tmp = {path=new_path,distance=distance,distance_so_far=distance_so_far}
 local swap
 while insert_index <= #obj.spot_q do
  swap = obj.spot_q[insert_index]
  obj.spot_q[insert_index] = tmp
  tmp = swap
  insert_index+=1
 end

 add(obj.spot_q,tmp)
 return false
end

local expand_next_spot = function(obj)
 if #obj.spot_q == 0 then
  obj.path = {path={}}
  return true
 end
 local next_spot = obj.spot_q[#obj.spot_q]
 obj.spot_q[#obj.spot_q] = nil

 local x = next_spot.path[#next_spot.path][1]
 local y = next_spot.path[#next_spot.path][2]

 local res = false

 local up = obj.check_can_pass(x,y-1)
 local down = obj.check_can_pass(x,y+1)
 local left = obj.check_can_pass(x-1,y)
 local right = obj.check_can_pass(x+1,y)

 local upright = obj.check_can_pass(x+1,y-1)
 local downright = obj.check_can_pass(x+1,y+1)
 local upleft = obj.check_can_pass(x-1,y-1)
 local downleft = obj.check_can_pass(x-1,y+1)

 -- do up,down,left,right with added_distance = 1
 if left then
  res = res or add_spot(obj, next_spot, x-1, y, 1)

  --left diagonals
  if down and downleft then
   res = res or add_spot(obj, next_spot, x-1, y+1, 1.41421)
  end
  if up and upleft then
   res = res or add_spot(obj, next_spot, x-1, y-1, 1.41421)
  end
 end
 if right then
  res = res or add_spot(obj, next_spot, x+1, y, 1)

  --right diagonals
  if down and downright then
   res = res or add_spot(obj, next_spot, x+1, y+1, 1.41421)
  end
  if up and upright then
   res = res or add_spot(obj, next_spot, x+1, y-1, 1.41421)
  end
 end
 if up then
  res = res or add_spot(obj, next_spot, x, y-1, 1)
 end
 if down then
  res = res or add_spot(obj, next_spot, x, y+1, 1)
 end

 obj.path = next_spot.path --this is mostly for debugging

 return res
end

function make_pathfinding(sx,sy,fx,fy,check_can_pass)
 local obj = {
  path = {},
  max_length = false,
  fx = fx,
  fy = fy,
  check_can_pass = check_can_pass,
  visited = {},
  spot_q = {}
 }

 add_spot(obj, {path={}, distance_so_far=0}, sx, sy, 0)
 obj.is_done = expand_next_spot(obj, check_can_pass)

 return obj
end

function expand_all_spots(obj)
 while not obj.is_done do
  obj.is_done = expand_next_spot(obj)
 end

 return obj.path
end

function find_path(sx,sy,fx,fy,max_length,check_can_pass)
 local obj = make_pathfinding(sx,sy,fx,fy,check_can_pass)
 obj.max_length = max_length
 return expand_all_spots(obj)
end

-- end ext

-- start ext ./main.lua
function _init()
 orig_field_of_view=1/6
 orig_draw_distance=10
 orig_height_ratio=.6
 distance_from_player_cutoff=.4
 mob_hitbox_radius=.45 -- this should be less than .5 but more than distance_from_player_cutoff
 height_scale=20 -- multiplier for something at distance of one after dividing by field of view
 orig_turn_amount=.01
 orig_speed = .1
 max_anxiety = 40
 panic_attack_duration = 150
 panic_attack_remaining = panic_attack_duration --this gets overwritten anyways

 --debug stuff, disable for release
 force_draw_width=false
 skip_update=false
 skip_draw=false
 debug=false
 --

 largest_width=0
 max_screenx_offset=0
 skipped_columns=0

 mobile_pool = make_pool()
 wall_pool = make_pool()
 player = makeplayer(false,makevec2d(39.4567,-30.3974),makeangle(.17))

 for x=0,127 do
  for y=0,-63,-1 do
   mob_id=mapget(x,-y)
   if is_sprite_mob(mob_id) then
    mobile_pool.make(make_sprite_by_id(mob_id, x, y))
   end
  end
 end

 reverse_strafe=false
 menuitem(1, "reverse strafe", function()
  reverse_strafe = not reverse_strafe
 end)

 --debug=true
 menuitem(2, "debug", function()
  if debug then
   debug = false
  else
   debug = true
  end
 end)

 menuitem(3, "respawn", respawn)

 local unfreeze_mobs_menu, freeze_mobs_menu

 function freeze_mobs_menu()
  freeze_mobs = true
  menuitem(4, "unfreeze mobs", unfreeze_mobs_menu)
 end

 function unfreeze_mobs_menu()
  freeze_mobs = false
  menuitem(4, "freeze mobs", freeze_mobs_menu)
 end

 unfreeze_mobs_menu()

 coin_count=0
 has_whisky=true
 has_key=true
 making_payment=false
 paid_for_whisky = false
 payment_progress = 0

 respawn()
end

function respawn()
 delays = makedelays(300) --max of 10 second delay

 field_of_view=orig_field_of_view -- 45*
 draw_distance=orig_draw_distance
 height_ratio=orig_height_ratio
 turn_amount=orig_turn_amount
 speed = orig_speed
 is_panic_attack = false

 current_anxiety=0
 anxiety_recover_cooldown=0
 player_bearing_v=0
 walking_step=0
 visual_anxiety = current_anxiety
 max_anxiety_diff = .3
 is_panic_anxiety_flash=false

 popup_duration = 0
 popup_text = ""
 popup_color = 8
 popup_blinking = false

 sky_color=1
 ground_color=0
 fog_color=0

 mobile_pool:each(function(m)
  m:reset_position()
 end)

 player:reset_position()

 --this is removing the whisky from their inventory if they haven't paid for it and they black out
 if has_unpaid_whisky() then
  for x=0,127 do
   for y=0,63 do
    mob_id=mapget(x,y)
    if is_sprite_mob(mob_id) then
     if mob_id == 16 then
      mobile_pool.make(makewhisky(mob_id,makevec2d(x,-y),makeangle(rnd())))
     end
    end
   end
  end

  has_whisky = false
 end

 mob_pos_map={}
 mob_round_map={}
 reset_mob_position_maps()
end

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

  local draw_close_fog = false
  local draw_far_fog = false

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
    draw_close_fog = true
   end

   if (distance > draw_distance) then
    found=true
    draw_far_fog = true
   else
    sprite_id=mapget(currx,-curry)
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

  if draw_close_fog or is_panic_attack then
   new_draw=deferred_fog_draw(pa,draw_distance*.9,draw_width,screenx)
   if new_draw then
    drawn_fog=true
    add(deferred_draws,new_draw)
   end
  end

  if draw_far_fog or is_panic_attack then
   new_draw=deferred_fog_draw(pa,draw_distance,draw_width,screenx,true)
   if new_draw then
    add(deferred_draws,new_draw)
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

function tick_anxiety()
 if anxiety_recover_cooldown > 0 then
  if is_panic_attack then
   popup("!panic attack!",2,8)
   panic_attack_remaining -= 1

   if panic_attack_remaining <= 0 then
    respawn()
    popup("yOU BLACKED OUT!",150,8)
    return
   end
  end

  anxiety_recover_cooldown -= 1/30
  return
 end

 is_panic_attack = false

 if current_anxiety >= 0 then
  current_anxiety-=.05+.005*current_anxiety
  if current_anxiety < 0 then current_anxiety=0 end
 end
end

function tick_bearing_v()
 if abs(player_bearing_v) > .0005 then
  player_bearing_v-= tounit(player_bearing_v)*.0005
  player.bearing+=player_bearing_v
 end
end

function tick_walking()
 walking_step+=.05
 if walking_step >= 1 then walking_step=0 end
end

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

 --adjusting height seems too confusing, leaving that for now
 --height_ratio = orig_height_ratio * (.8 + anxiety_factor*.2)

 speed = orig_speed * (2 - anxiety_factor)

 anxiety_vertical_offsets_scalar = 1 - anxiety_factor
end

function add_anxiety()
 current_anxiety+=3
 if current_anxiety >= max_anxiety then
  current_anxiety = max_anxiety

  if not is_panic_attack then
   reset_anxiety_offsets()
   panic_attack_remaining = panic_attack_duration
  end

  is_panic_attack = true
 end
 anxiety_recover_cooldown = 10
end

function add_to_map(map,x,y,mob)
 map[x] = map[x] or {}
 map[x][y] = map[x][y] or {}
 add(map[x][y],mob)
end

function reset_mob_position_maps()
 mob_pos_map={}
 mob_round_map={}
 local x,y,next_coords
 mobile_pool:each(function(mob)
  for x=flr(mob.coords.x),ceil(mob.coords.x) do
   for y=flr(mob.coords.y),ceil(mob.coords.y) do
    add_to_map(mob_pos_map,x,y,mob)
   end
  end

  --pathfinding stuff below

  if mob.sprite_id == debug_marker_id then
   return
  end

  if mob:is_on_path() then
   next_coords = mob:next_coords()
   add_to_map(mob_round_map,next_coords.x,next_coords.y,mob)
   next_coords = mob:next_coords(1)
   if next_coords then
    add_to_map(mob_round_map,next_coords.x,next_coords.y,mob)
   end
  else
   add_to_map(mob_round_map,round(mob.coords.x),round(mob.coords.y),mob)
  end
 end)
end

function _update()
 if skip_update then
  return
 end
 delays.process()

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



 local curr_tile_sprite_id=mapget(round(player.coords.x),round(-player.coords.y))
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

 update_panic_offsets()

 reset_mob_position_maps()
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
 if is_panic_attack then
  rectfill(0,0,127,63,8) --red sky
  rectfill(0,64,127,127,0)
 else
  rectfill(0,0,127,63,sky_color)
  rectfill(0,64,127,127,ground_color)
 end
 draw_stars()
end

function draw_anxiety_bar()
 rectfill(54,1,126,6,0)
 rectfill(83,2,125,5,1)

 anxiety_color = 5 --dark gray
 if current_anxiety > 0 then
  local anx_pixels = (125-83) / max_anxiety * current_anxiety
  rectfill(83,2,min(83+anx_pixels,125),5,7) --white bar for added anxiety
  local disp_pixels
  if is_panic_attack then
   disp_pixels = 125-83
  else
   disp_pixels = (125-83) / max_anxiety * visual_anxiety
  end
  rectfill(83,2,min(83+disp_pixels,125),5,8)

  if is_panic_attack then
   if is_panic_anxiety_flash then
    anxiety_color = 8
   end
   is_panic_anxiety_flash = not is_panic_anxiety_flash
  elseif current_anxiety > visual_anxiety then
   anxiety_color = 7
  else
   anxiety_color = 6 --med gray
  end
 end
 print("ANXIETY",55,1,anxiety_color)
end

function add_coin()
 popup("fOUND A COIN!",30,10,true)
 coin_count+=1
end

function clear_coins()
 coin_count=0
end

function add_key()
 popup("rECEIVED HOUSE KEY!",30,12,true)
 has_key=true
end

function fail_go_home()
 popup("nEED THE KEY! gET AT LODGE",30,12)
end

function add_whisky()
 popup("pICKED UP WHISKY!",30,9,true)
 has_whisky=true
end

function fail_whisky()
 popup("nOT ENOUGH COINS, NEED 5!",20,9)
end

function fail_steal_whisky()
 popup("cAN'T LEAVE WITHOUT PAYING!",30,9)
end

function has_unpaid_whisky()
 return has_whisky and coin_count > 0
end

function fail_enter_lodge()
 popup("byob! nO FREELOADERS!",30,9)
end

function make_payment()
 if has_unpaid_whisky() then
  popup("pAYING FOR WHISKY...",10,11)
  making_payment = true
 end
end

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
 if has_key then
  spr(65,113,8) -- -8 because the whisky is a little narrow
 end
end

function _draw()
 draw_start_time = stat(1)
 if (skip_draw) then
  cls()
 else
  draw_background()

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
00000000006660000000000055555555000000000000000000000000111111111111111100000000000000000000000066666666c0c0c0c00000000067676767
00000a0000666000000000005cccccc50000000000000000000000001111111111111111000600000000000000000000600000060000000c0000000044444444
00aaa0000a666a00000000005ccc6cc50000000000000000000000001111111111111111006660000000000000000000600c0006c000000000fff00000000c00
00fff00000fff000000000005c6cc6c5000000000110555500000000111111111111111100fff000000000000000000060c00c060000c00c00fff0000c00c000
0fefef000fefef00000000005cc6ccc50000000011115bb50000000000000000333333330fefef0000000000000000006000c006c00c00000fefef00c00c0000
00fff00000fff0000b0ccb085ccc6cc5000000001111001000000000000000003333333300fff0000b0a0080a0080000600c00060000000c00fff0000000000c
000f0000000f00009b8ccbec5c6cc6c50000000011110010000000000000000033333333000f0000b00b00b0b00b0e0060c00c06c0000000000f00000c000c00
0666660006666600777777775cc6ccc566666666666666660000000000000000333333330787870030b3b3bc3b0b030b6000c0060c0c0c0c0aaaaa00c000c000
66666660666666605e555b555cccccc577777776777777760000000077777777777777777787877000000000000000006000000699999999aaaaaaa0000c000c
6066606060666060ae8c9bee5666666577777776777777760000000077777777777777777088807000000000000000006666666640000004a0aaa0a000000000
6066606060666060ae8c9bee5555555577777776777777760000000077777777777777777088807000000000000000007777777740000004a0aaa0a000000c00
6099906060999060777777775cccccc577777776777777760000000077777777777777777088807000000000000000007666666744444444a0aaa0a00c00c000
00ccc0000099990055a555c55c6c6cc57777777677777776000000002222222255555555005550000000000000000000767777674444444400aaa000c00c0000
00c0c0000099990038a99ac85cc6c6c577777776777777760000000022222222555555550050500000200b0a0000000b767777674000000400a0a0000000000c
00c0c00000f0f00038a99ac85cccccc577777776777777760000000022222222555555550050500000b0b00b0b00b0b0766666674000000400a0a00044444444
00909000008080007777777755555555777777767777777600000000222222225555555500404000c3b030b3b303b030777777774000000400a0a00012121212
665566550000000066556655665566550000000000000000cc7777cc77cc77cccc7777cc7777cccc000000000000000000000000000000000000000000000000
4444444400000cc04444444444444444000000000000000055444455445544555544445544445555000000000000000000000000000000000000000000000000
711111170000cccccc77cc7700000c0000000000000000001111111dc7c7c7c71d6d6d1dc7c7c7c7000111111111110000000000000000001111111111111111
71cccc17ccccc00ccc67cc670c00c0000000000000000000d1cccc117c7c7c7cd1d6d6d17c7c7c7c000144491144410000111111000000001c1c777ccccc7771
71cccc17c0ccc00c766c766cc00c0000000000000000000011cccc1dc7c7c7c71d6d6d1dc7c7c7c71111141999414100111333d1111110001ccc717c1c1c7711
61ccc11600c0c00c67cc67cc0000000c0000000000000000d1ccc1117c7c7c7cd1d6d6d17c7c7c7c1411141949441100188837ddd99910001c1c777c1c1c7771
61cccc160000cccc6c766c760c000c00888888888888777711cccc1dc7c7c7c71d6d6d1dc7c7c7c71411141949144111187837d7d97911111771111111111111
71cccc1700000cc0cc77cc77c000c0008888888888887777d1cccc11fcfcfcfcd1d6d6d1fcfcfcfc141999444999444118773ad7d997eee117c1c1c777ccc711
717ccc170000000077cc77cc000c000c8888888888887777117ccc1dcfcfcfcf1d6d6d1dcfcfcfcf14191941491941411888aaaccc99e7e1177c1c1771cc7771
617cc1160000000067c667c6000000004444444444444444d17cc1117c7c7c7cd1d6d6d17c7c7c7c141919414919441117787a7c7cbbee71117c1c1777ccc711
617ccc1600000000cc76cc7600000c004444444444444444117ccc1dc7c7c7c71d6d6d1dc7c7c7c7144999444999144118887a7cccb77ee11771111111111711
71cccc1700000000c667c6670c00c0004000000540000004d1cccc117c7c7c7cd1d6d6d17c7c7c7c111111111119111111111111111111111c1c777ccccc7771
71cccc170000000076cc76ccc00c0000400000054000000411cccc1dc7c7c7c71d6d6d1dc7c7c7c7000000001999100000000000000000001ccc717c1c1c7711
71ccc1170000000077cc77cc0000000c4000000540000004d1ccc1117c7c7c7cd1d6d6d17c7c7c7c000000001111100000000000000000001c1c777c1c1c7771
54cccc54000000005454545454545454400000054000000454cccc54545454545454545454545454000000000000000000000000000000001111111111111111
21cccc21000000002121212121212121400000054000000421cccc21212121212121212121212121000000000000000000000000000000000000000000000000
00000000000b4800000000009b009080656565650000000000000000757575757eee7eeeccccccccc9c9c9c9c7c7c7c700000000000000000000000000000000
000000000900a4bb00000000390940b95006088630003030000000006666666678887888cccccccc9c9c9c9c7c7c7c7c00000000000000000000011100000000
00000000bb353b44000000008b948093588602263a9039300000000065556555ee7eee7eccccccccc9c9c9c9c7c7c7c70000011110000000000001b111111000
0000000044cb55b3000080000949b93b52268b06390a3a03000000006555655588788878dddddddd9c9c9c9c7c7c7c7c000001ab31100000001111b444cc1000
000000003b44b35b0c00b00a94b494085b060b06030a990a00000000666666667eee7eeeccccccccc9c9c9c9c7c7c7c70000011b1c111111001888bbbbc41000
00000000b55b44b30b3b3b0b490949b06565656533090a09000000005565556578887888cccccccc9c9c9c9c7c7c7c7c0000001b1b338331001484b44bcc1000
77777777e3b53b443b3233b3b494089058260b86309a090a0000000066666666ee7eee7eccccccccc9c9c9c9c7c7c7c7111110111b13b1311114844444c41000
7777777744b953b33db3b39b09498b495b068b0630a30a39000000006555655588788878dddddddd9c9c9c9c7c7c7c7c1c3910011111b3111bbb8444bbbc1100
787878783b4b3b3b4999999494b490945b060b063a93093a00000000655565557eee7eeeccccccccc9c9c9c9c7c7c7c71b131111831113211b4b4aaab44be100
87878787b3244b5324444442490349805886088639030a39000000006666666678887888cccccccc9c9c9c9c7c7c7c7c1b311311b131a1111bbbaa4abbb4e100
48787874353344bb499999948b9b943b522602263a03093a0000000055655565ee7eee7eccccccccc9c9c9c9c7c7c7c71b11e131b311b1d11b4aaaaaba4be111
4087870443b5bc44494f4f9403484b4965656565390390a9000000006666666688788878dddddddd9c9c9c9c7c7c7c7c1111b331b131b3111b4a1111ba4be4e1
40000004b44a53bb49f4f4940b9490945b060b063a33a09a00000000655565557eee7eeeccccccccc9c9c9c9c7c7c7c70001b1311111b191111110011111ee41
400000043b4b3b53494f4f94894b49485b868b06393093a9000000006555655578887888cccccccc9c9c9c9c7c7c7c7c0001111100011111000000000001e4e1
4000000453b44b35249999429403949b50b60b863a3a03930000000066666666ee7eee7eccccccccc9c9c9c9c7c7c7c700000000000000000000000000011111
40000004400334442244442240b9404950b60b06393903a3000000007575757588788878dddddddd9c9c9c9c7c7c7c7c00000000000000000000000000000000
a0000000f200000000000050000000060600000000000020100000101088008800001010000010000000000024000000000000002424042424242400008000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000f2000000120000f2000000060600000000000020100000101000000000001010000010767600000034000000000000002400000000002400008000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000020424242424200f20000000000000000060600f2100000101010101010101010000010e47600000034000000000000000400000000002400008000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000020202020202020200000000606001200060600f2100000101010101010101010000010f47600000024000000000000002400000000002400008000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000020424242424242200000000606000000120000f2100000000000000000000000000010767600000024242424242424242424242424242400008000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000f200000000000050000000001200000006060020100000000000000000000000000010800000000000000000000000000000000000000000008000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000f2000000120000f200000006060000000606002010101010101010101076d4c4761010800000000000000000000000000000000000000000008000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000020424242424200f20000000606001200120000200000f0f0f0f0f032f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f032f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000020202020202020200000001200000000060600200000f0222222000000222222222222222222222222220042920000009242000000d04242420000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000020424242424242200000000606000000060600f20000f0220000000000000000000000000000000000000042524242425242000000d04200000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000f2000000000000500000000606000000120000f20000f0220000000000000000000000000000000000000000000000000000000002d00000000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000f2000000120000f20000120012001200000000f20000f0220000000000000000000000000000000000000000000000000000000000d01200d0d0d0f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000020424200004200f20000000000000000000000200000f0222222220000000000000000000000002222222222222222222222220000d00000000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000202020f2f220202020f2f2205020f220f2f220200000f0f0f0f0f0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000d04200000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000008040000000404040400000000012008000000000000000000000f042000000c0222222f02200000000000000000000000000000000d04242000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000080401200000000000000000000f0008000000000000000000000f042000000c0000012f02200002222222222000022222222220002d0d0d0d0d032f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000008040120000000000121200000002008000000000000000000000f042000000c0000000f02202000000000000000000000000000000220000000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000008040120000000002424202000000008002000000000000000000c20000000000000022f02200020000000000000000000000000200220000000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000009000000000000002424202000002009000000000000000000000c20000010000000022f02222222200002222222222000022222222220000c00000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000080000000000000001212000000f0008000000000000000000000c20000000000000022f00000000000000000000000000000000000001200c00000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000008000000000000000000000000012008000000000000000000000f042000000c0000000f00000000002000000000000000000000000000000c00000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000800012f0120012f0120012f01200008000000000000000000000f042000000c0000000f00000c00000c00000c00000c00000c00012c00000c00000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000008000000000000000000000000000008000000000000000000000f042000000c0000000f00000c00000c00000c00012c00000c00000c00000c00000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000009000000090909090909090909090909080808080908080808090f0c0c0c0c0c0000000f00002c00000c00002c00000c00000c00000c01200c00000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000007000000000000000000000000000000000000000000000000000c20012000000000000000000000000000000000000000000000000000000000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000b000000000000000000000000000001000100010001000140000c20000000000000000000000000000000000000000020000000000000000000000f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000007002000000000000000000000000000000000000000000000000c22222222222000000222222222200000022222200000022222200000022222222f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000009080808080908080808090808080809080808080908080808090f0f0f0f0f0f0c2c2c2f0f0f0f0f0c2c2c2f0f0f0c2c2c2f0f0f0c2c2c2f0f0f0f0f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000000000000000000000000000000000000000000000000000000000000000000000b20000000000000000b2000000a2000000000000000000000000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000009000009000009000009000000000000000000000000000000000000000000000b300a30000000000a20000000000000000000000b3b200a2000000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000000000000000000000000000000000000000000000000000000000000000a2a3b20000a200a300a3000000a3b2b2b300b200a300a200a300a3a30000a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0
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
000d0000010a00010101000b00000000848400000000000000000000000000008080010a0101004040800d0d01048001000000008080004040000d0d000d00000a84000101010a000000010101010101000000000000000000000000000000000100010101010000000000000101010100000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060a0000002f00000000000005000000606000000000000002010000010100002b000001010000010000000000420000000000000042424042424242000008000a
060000000006000000000000000021000065006500650000002100000000000600000100010001000000200000000600000000000000000000000720000000060a0000002f0000002100002f0000006060000000000000020100000101000000000001010000016767000000430000000000000042000000000042000008000a
0600000000000700073a2a000000000000210000210000000000000000000006000001000100010000200020000006000600002000002a0600000720000000060a000000022424242424002f00000000000000006060002f0100000101010101010101010000014e67000000430000000000000040000000000042000008000a
0600002100000007002b2a000000000000000000000000000000000000000006000000000707070706060606000006060606060606062b0600000606060000060a000000020202020202020200000060600021006060002f0100000101010101010101010000014f67000000420000000000000042000000000042000008000a
06000000002106000006000606066406060606210000002164000000000000062b2a2b2a070000000600000000000000000000000000000600000000060000060a000000022424242424240200000060600000002100002f0100000000000000000000000000016767000000424242424242424242424242424242000008000a
06210000000006000607000000000606210000066406090706000000010101060101012b070000000600060606060606070707070606060606060600060000060a0000002f000000000000050000000021000000606000020100000000000000000000000000010800000000000000000000000000000000000000000008000a
06002100000000070000060006000000000000000600070000060607011101060111012a070000210620070000000006000000000000000000000000060000060a0000002f0000002100002f0000006060000000606000020101674d4c670101010101010101010800000000000000000000000000000000000000000008000a
0600000000002a000000000700000600210006000000000000000007010101060101012b070000000607070000000006070707060606060600000000060000060a000000022424242424002f00000060600021002100000200000f0f0f0f0f230f0f2c2c2c0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f230f
060000000007000007000000060000060607000600000000000000060707070607070706070006060600000006060000000000000000000000000000000000060a000000020202020202020200000021000000006060000200000f2222220000002200000022222222222222222200242900000029240000000d24242400000f
060007000007000000070000000000060000000000000000000600060000000000000006000000000000202006060000003b3b000000000000000000000000060a000000022424242424240200000060600000006060002f00000f2200000000000000000000000000000000000000242524242425240000000d24000000000f
06000007000700000000000000000600000700000007000700000006002a0000002b0006070707060606060606060606063a2b060606060606060606060606060a0000002f0000000000000500000060600000002100002f00000f2200000000000000000000000000000000000000000000000000000000200d00000000000f
062100000007000000070007000000000006000700000000000000000000010101000000000000000000000000000000012a3a0100000000000000003a073a190a0000002f0000002100002f00002100210021000000002f00000f2200000000000000000000000000000000000000000000000000000000000d21000d0d0d0f
060707000000070000000000000000070000000000070000000600000000011101000000000000000000000000000000013a2b0100000000000000002a072b190a000000022424000024002f00000000000000000000000200000f2222222200000000000000000000000022222222222222222222222200000d00000000000f
060000072100070006000000000000000000000000000000000000000000010101000000000000000000000000000000012a3a0100000000000000002b072a190a0000000202022f2f020202022f2f0205022f022f2f020200000f0f0f0f0f0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000d24000000000f
06000000000000070007070000200707070606060707070706060607003a0000003b0007070606060606060606060000010101010000060606060000060606060a00000008040000000404040400000000210008000000000000000000000f240000000c2222220f22000000000000000000000000000000000d24240000000f
06000000070000000000000707070000000007000000072b0000000700000000000000070000002a0000000000060000000000000000060000000000000021060a000000080421000000000000000000000f0008000000000000000000000f240000000c0000210f22000022222222220000222222222200200d0d0d0d0d230f
06000700000007000007000020000007000000060600072a0606000707070000000707070b06060000000000000600000000000000000600000f00000f0000060a00000008042100000000002121000000200008000000000000000000000f240000000c0000000f22200000000000000000000000000000002200000000000f
060000000000000000070000070007000006000000000700060000000006000000070000000006000000200000060606060606060606060000000000000000060a00000008042100000000202424200000000008200000000000000000002c00000000000000220f22002000000000000000000000000020002200000000000f
060000070700000700000007000007000006000007000000070000000006000000072a2b2a2b0600000000000000000000000b000000060000000000000000060a00000009000000000000202424200000200009000000000000000000002c00001000000000220f22222222000022222222220000222222222200000c00000f
060000000000000700000000000007000000000000000000072a2b2a2b06000000070101012a060000210000200000000000060000000600000f00000f0000060a000000080000000000000021210000000f0008000000000000000000002c00000000000000220f00000000000000000000000000000000000021000c00000f
060606060606060606060606060606060606060606060607072b01010106000000070111012b06000000000000000000000006000000060000000000000000060a00000008000000000000000000000000210008000000000000000000000f240000000c0000000f00000000200000000000000000000000000000000c00000f
0a0000000000000000000000000000000000000000000000072a01110106000000060101012a06000020002100000021000006000000060606060606070707060a0000000800210f2100210f2100210f21000008000000000000000000000f240000000c0000000f00000c00000c00000c00000c00000c00210c00000c00000f
0a0000000000000000000000000000000000000000000000072b010101060000000606060606060000000000000000000000060000000000000000000000000a0a00000008000000000000000000000000000008000000000000000000000f240000000c0000000f00000c00000c00000c00210c00000c00000c00000c00000f
0a0000000000000000000000000000000000000000000000060607070706000000676c6d6706060606060606060606060606060606060606060606060606000a0a00000009000000090909090909090909090909080808080908080808090f0c0c0c0c0c0000000f00200c00000c00200c00000c00000c00000c21000c00000f
0a0000000202022f2f2f0202022f2f2f0202022f2f2f0202010101010101010101010101010101080000000000000000000000000000003a2b002b002b08000a0a00000007000000000000000000000000000000000000000000000000002c00210000000000000000000000000000000000000000000000000000000000000f
0a0000002f242400000024020000000004040400000004020100000000000000000000000000010800000000000000000000000000003a2a2b3b003a0008000a0a0000000b000000000000000000000000000001000100010001004100002c00000000000000000000000000000000000000002000000000000000000000000f
0a0000002f0000000000240200000000000000000000000267000000000000000000000000000108000000004242424242424242424242434242423b3a08000a0a00000007200000000000000000000000000000000000000000000000002c22222222220000002222222222000000222222000000222222000000222222220f
0a00000005000000000000050000000000000021000000024b000001010101010101010100000108000000004200000000000000420000004445423a0008000a0a00000009080808080908080808090808080809080808080908080808090f0f0f0f0f0f2c2c2c0f0f0f0f0f2c2c2c0f0f0f2c2c2c0f0f0f2c2c2c0f0f0f0f0f
0a0000002f0000000000002f0000000000000000000000024a000001010101010101010100000108000000004300000000000000420000000000422a3a08000a0a0000000000000000000000000000000000000000000000000000000000000000000000002b00000000000000002b0000002a0000000000000000000000000a
0a0000002f0024242424002f00000000000000000000000267000001010000000000010100000108000000004300000000000020420000000000433b0008000a0a00000009000009000009000009000000000000000000000000000000000000000000003b003a00000000002a00000000000000000000003b2b002a0000000a
0a0000000202020202020202000021000000000000000002010000010100003a000001010000010000000000420000000000002040000000000042000008000a0a00000000000000000000000000000000000000000000000000000000000000002a3a2b00002a003a003a0000003a2b2b3b002b003a002a003a003a3a00000a
0a00000002242424242424020000000000000000000000050100000101002b3a3b0001010000010000000000400000000000002042000000000042000008000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a
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

