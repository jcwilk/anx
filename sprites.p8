pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
--aNX
--BY jOHN wILKINSON

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

-- START LIB
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
    if(is_other_mob(mob,x,y)) return false
    local sprite_id = mapget(x,-y)
    if(not is_sprite_wall(sprite_id)) return true
    return (not is_sprite_wall_solid(sprite_id)) and (not is_sprite_door(sprite_id))
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

-- END LIB

__gfx__
000000000066600067676767bbbbbbbb900000096767676730030b5030300b5300000000000000000b00b03b30030b5000000000000000000000000000000000
00000a000066600044444444bbbbbbbb090000904444444433853b3333803b330000000000000000b00b1bb03555555300000000000000000000000000000000
00aaa0000a666a0049494949bbbbbbbb009999004666666933b334b333b334b3000000000000000031b311313510105300000000000000000000000000000000
00fff00000fff00049494949bbbbbbbb0000000046555569b3335bb4b3330bb40f000f0000000000311b1bb1b501015400000000000000000000000000000000
0fefef000fefef0049494949bbbbbbbb00000000465555694b45b3334b45b00349f049f000000000b113113b4510105300000000000000000000000000000000
00fff00000fff00049494949bbbbbbbb00000000465555693b354b333b054b0349f049f000800b0a3b1bb1313501015300000000000000000000000000000000
000f0000000f000049494949bbbbbbbb0000000046555569b33334bbb00004bb49f049f000b0b00b311311bbb510105b00000000000000000000000000000000
066666000666660049494949bbbbbbbb77777777466666694b55233b4b55200b49f049f0b3bc3bb331b311314501066b00000000000000000000000000000000
6666666066666660494949490000000066666666465555693b33b53b3b00b50bffffffff54445444311b1bb13510166b00000000000000000000000000000000
60666060606660604949494900000000666666664655596934bb35b434bb05b44444444449494949b113113b3501015400000000000000000000000000000000
606660606066606049494949000000006666666646555569eb45334beb45004b9999999949f949f93113b131e510105b00000000000000000000000000000000
60999060609990604949494900000000660000664655556934b3353b34b0050b4444444447f747f73b1b11bb3501015b00000000000000000000000000000000
00ccc00000999900494949490000000040000004465555693b4395b43b4095b412201220ffafffafb11311313510105400000000000000000000000000000000
00c0c00000999900494949490000000040000004465555693b533b433b500b4349f049f047f747f731b31bb13501015300000000000000000000000000000000
00c0c00000f0f0004444444400000000400000044655556434b553b334b553b349f049f049f949f9311b11313510105300000000000000000000000000000000
009090000080800012121212000000004000000416666662354b33b5354b33b549f049f049494949311311313555555300000000000000000000000000000000
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

__gff__
0000000001020001010100030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0202020202020202020202020202020600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000020600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200040000040000000000000000050b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200040000040000000000000000020600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200040000040000000000020000020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200040000040000000000020000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000020000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000020000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000020000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020502020202020202020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0606060606060b06060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000000000060000060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000000000070000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000606070606060000060000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000060000060000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600000000000000060000060000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0606060606060000070000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000060000060000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000060000060606060606060a0a0a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000008080800000000000000000800000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a090008000000000000000000000800090a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000008000000000909090900000800000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000008000000000000000000000800000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a090008000000000000000000000800090a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000008080808080808080808080800000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a090000090000090000090000090000090a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

