pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
--aNX
--BY jOHN wILKINSON
-- start ext ./utils.lua
function trunc(n)
return flr(n)
end
function towinf(n) 
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
end
delay_store[tick_index] = {}
end
local function make(fn, delay)
delay = mid(1,flr(delay),max_ticks)
local delay_to_index = (tick_index + delay) % delay_store_size
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
return sprite_id == 5 
end
function is_sprite_home_door(sprite_id)
return sprite_id == 64 
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
function calc_fisheye_correction(angle)
local adjusted = (angle.val-player.bearing.val) % 1
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
local vertical_clamp_scale = 5 
local z_clamp_scale = .5
if is_panic_attack then
for x=1,4 do
for y=1,4 do
offsetsx[x][y] += (rnd()-.5)*2
offsetsy[x][y] += (rnd()-.5)*2
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
local sprite_height=fisheye_correction*height_scale/distance/field_of_view
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
offsetx = offsetsx[pixel_col % 4 + 1][i % 4 + 1]
offsety = offsetsy[pixel_col % 4 + 1][i % 4 + 1] + verticaloffset
thisxleft += offsetx
thisxright += offsetx
thisybottom += offsety
thisytop += offsety
rectfill(thisxleft,thisytop,thisxright,thisybottom,colr)
end
end
end
else
obj.draw=function(obj)
local width = (screenxright - screenxleft + 1) + round(extra_overlap*2)
screenxleft -= round(extra_overlap)
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
local side_length=(width_vector*normal_vec_to_mob)/8 
local face_length=mob_bearing:tovector()*normal_vec_to_mob 
local side_to_left=side_length*face_length<0 
local angle_to_mob = vec_to_mob:tobearing()
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
if is_sprite_half_height(mob.sprite_id) then 
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
if face_length < 0 then
pixel_color=sget(col_i+spritex,row_i+spritey)
else
pixel_color=sget(7-col_i+spritex,row_i+spritey)
end
vertical_offset=verticaloffsets[col_i+1]
if mob.sprite_id == debug_marker_id and pixel_color > 0 then
pixel_color = mob.overwrite_color
else
if pixel_color == 14 then
if face_length <= 0 then
if is_panic_attack then
pixel_color=8 
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
if screen_width < 1 then 
mob_data.columns={}
end
cached_mobs[mob.id]=mob_data
return mob_data
end
function deferred_mob_draw(mob,dir_vector,screenx,draw_width)
local mob_data=cache_mob(mob,dir_vector,screenx,draw_width)
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
rectfill(side.xo,row.yo+side.offset,side.xf,row.yf+side.offset,side.color)
end
elseif mob_data.side_length <= -1 then
for i=#row.sides,1,-1 do
side=row.sides[i]
rectfill(side.xo,row.yo+side.offset,side.xf,row.yf+side.offset,side.color)
end
end
end
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
mob.path = find_path(round(mob.coords.x), round(mob.coords.y), round(player.coords.x), round(player.coords.y),8,function(x,y)
return check_can_pass(mob,x,y)
end)
mob.path_index = 1
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
end
if (not mob.path or mob.path_index > #mob.path) and distance < 4 and mob.is_pathfinding then
if not reset_mob_path(mob) then
mob.is_pathfinding = false
local deferred = function()
mob.is_pathfinding = true
end
delays.make(deferred, rnd(30)+30) 
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
end
mob.path_index += 1 
next_coords = mob:next_coords()
end
if next_coords then
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
update=follow_path
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
if obj.visited[newx] then
if obj.visited[newx][newy] and obj.visited[newx][newy] < distance_so_far + .001 then
return false 
end
else
obj.visited[newx] = {}
end
obj.visited[newx][newy] = distance_so_far
if newx == obj.fx and newy == obj.fy then
return true 
end
if obj.max_length and obj.max_length <= #old_spot.path then
return false
end
local new_path = {}
for sindex = 1,#old_spot.path do
add(new_path,old_spot.path[sindex])
end
add(new_path,{newx,newy})
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
if left then
res = res or add_spot(obj, next_spot, x-1, y, 1)
if down and downleft then
res = res or add_spot(obj, next_spot, x-1, y+1, 1.41421)
end
if up and upleft then
res = res or add_spot(obj, next_spot, x-1, y-1, 1.41421)
end
end
if right then
res = res or add_spot(obj, next_spot, x+1, y, 1)
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
obj.path = next_spot.path 
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
mob_hitbox_radius=.45 
height_scale=20 
orig_turn_amount=.01
orig_speed = .1
max_anxiety = 40
panic_attack_duration = 500
panic_attack_remaining = panic_attack_duration 
force_draw_width=false
skip_update=false
skip_draw=false
debug=false
largest_width=0
max_screenx_offset=0
skipped_columns=0
mobile_pool = make_pool()
wall_pool = make_pool()
player = makeplayer(false,makevec2d(29.5244,-30.2927),makeangle(.7902))
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
menuitem(2, "respawn", respawn)
local unfreeze_mobs_menu, freeze_mobs_menu
function freeze_mobs_menu()
freeze_mobs = true
menuitem(4, "unfreeze mobs", unfreeze_mobs_menu)
end
function unfreeze_mobs_menu()
freeze_mobs = false
menuitem(4, "freeze mobs", freeze_mobs_menu)
end
coin_count=0
has_whisky=false
has_key=false
making_payment=false
paid_for_whisky = false
payment_progress = 0
respawn()
setup_intro_text()
end
function setup_intro_text()
popup("iT'S BEEN A LONG NIGHT.",60,8,false,function()
popup("tHE LODGE IS SO TIRING.",60,8,false,function()
popup("yOU LOST YOUR KEY OUT BACK.",60,8,false,function()
popup("yOU'RE SPENT TO HELL.",60,8,false,function()
popup("yOU JUST WANT TO GO HOME.",90,5,false,function()
end)
end)
end)
end)
end)
end
function setup_win_text()
popup("yOUR BODY COLLAPSES INTO BED.",150,7,false,function()
popup("yOU TRY TO FORGET. . .",150,7,false,function()
popup(". . .THE CROWDS OF EYES.",250,7,false,function()
extcmd("reset")
end,81)
end,81)
end,81)
end
function respawn()
delays = makedelays(300) 
field_of_view=orig_field_of_view 
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
popup_on_complete = false
popup_sprite_id = false
sky_color=1
ground_color=0
fog_color=0
mobile_pool:each(function(m)
m:reset_position()
end)
player:reset_position()
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
failed_blip_delaying=false
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
function ce_heap_sort(data)
local n = #data
if n == 0 then
return
end
for i = flr(n / 2) + 1, 1, -1 do
local parent, value, m = i, data[i], i + i
local key = value.key
while m <= n do
if ((m < n) and (data[m + 1].key > data[m].key)) m += 1
local mval = data[m]
if (key > mval.key) break
data[parent] = mval
parent = m
m += m
end
data[parent] = value
end
for i = n, 2, -1 do
local value = data[i]
data[i], data[1] = data[1], value
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
local alotted_time=total_time-start_time
local buffer_time=buffer_percent*alotted_time
start_time+=buffer_time
alotted_time-=buffer_time
skipped_columns=0 
local found_mobs
local new_draw 
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
if is_panic_attack then
music(0,1000)
end
is_panic_attack = false
if current_anxiety >= 0 then
current_anxiety-=.05+.005*current_anxiety
if current_anxiety <= 0 then
music(-1,1000)
current_anxiety=0
end
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
local anxiety_diff = current_anxiety - visual_anxiety
local max_diff = max(abs(anxiety_diff/10),max_anxiety_diff)
visual_anxiety+= mid(-max_anxiety_diff,anxiety_diff,max_anxiety_diff)
local downscale_anxiety = .4 
local anxiety_factor = -2/(-visual_anxiety*downscale_anxiety-2)
fisheye_ratio = (1 - anxiety_factor) * 3
height_ratio = .44+.08*abs(sin(walking_step))+.15*anxiety_factor
draw_distance = orig_draw_distance * (1/4 + 3/4*anxiety_factor)
turn_amount = orig_turn_amount * (2 - anxiety_factor)
speed = orig_speed * (2 - anxiety_factor)
anxiety_vertical_offsets_scalar = 1 - anxiety_factor
end
function add_anxiety()
if current_anxiety <= 0 then
music(0)
end
current_anxiety+=3
if current_anxiety >= max_anxiety then
current_anxiety = max_anxiety
if not is_panic_attack then
music(1,1000)
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
if (not has_won) and player.coords.x > 54 and player.coords.x < 58 and player.coords.y > -29 and player.coords.y < -26 then
has_won = true
setup_win_text()
end
if has_won then
update_popup()
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
rectfill(0,0,127,63,8) 
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
anxiety_color = 5 
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
if is_panic_attack then
if is_panic_anxiety_flash then
anxiety_color = 8
end
is_panic_anxiety_flash = not is_panic_anxiety_flash
elseif current_anxiety > visual_anxiety then
anxiety_color = 7
else
anxiety_color = 6 
end
end
print("ANXIETY",55,1,anxiety_color)
end
function add_coin()
play_pickup_blip()
popup("fOUND A COIN!",30,10,true)
coin_count+=1
end
function clear_coins()
coin_count=0
end
function play_pickup_blip()
sfx(4)
end
function play_failed_blip()
if not failed_blip_delaying then
sfx(5)
failed_blip_delaying = true
delays.make(function()
failed_blip_delaying=false
end, 2*30)
end
end
function add_key()
play_pickup_blip()
popup("rECEIVED HOUSE KEY!",30,12,true)
has_key=true
end
function fail_go_home()
play_failed_blip()
popup("nEED THE KEY!",30,12,false,function()
popup("cHECK BEHIND THE LODGE",30,12,false,false,65)
end,65)
end
function add_whisky()
play_pickup_blip()
popup("pICKED UP WHISKY!",30,9,true)
has_whisky=true
end
function fail_whisky()
play_failed_blip()
popup("nOT ENOUGH COINS, NEED 5!",30,9,false,function()
popup("lOOK IN THE PARK",30,9,false,false,17)
end,17)
end
function fail_steal_whisky()
play_failed_blip()
popup("cAN'T LEAVE WITHOUT PAYING!",30,9,false,false,37)
end
function has_unpaid_whisky()
return has_whisky and coin_count > 0
end
function fail_enter_lodge()
play_failed_blip()
popup("byob! nO FREELOADERS!",30,9,false,function()
popup("bUY AT THE STORE",30,9,false,false,16)
end,16)
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
function popup(text,duration,colr,blinking,on_complete,sprite_id)
popup_duration = duration
popup_text = text
popup_color = colr
popup_blinking = blinking
popup_on_complete = on_complete
popup_sprite_id = sprite_id
end
function update_popup()
if popup_duration > 0 then
popup_duration-=1
if popup_duration == 0 and popup_on_complete then
local callback = popup_on_complete
popup_on_complete = false
callback()
end
end
end
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
if popup_sprite_id then
local offset=4
rectfill(58,textyo-pb1-12+offset,69,textyo-pb1-1+offset,0)
rect(58,textyo-pb1-12+offset,69,textyo-pb1-1+offset,1)
spr(popup_sprite_id,60,textyo-pb1-10+offset)
end
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
spr(16,128-coin_count*9-8,8) 
end
if has_key then
spr(65,113,8) 
end
end
function _draw()
draw_start_time = stat(1)
if (skip_draw) then
cls()
else
if has_won then
cls()
else
draw_background()
raycast_walls()
draw_anxiety_bar()
draw_inventory()
end
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
000000000000000049494949bbbbbbbb0000000046555569b3335bb4b3330bb40000000000000000311b1bb1b501015477777777777777776666666676767767
000000000000000049494949bbbbbbbb00000000465555694b45b3334b45b0030000000000000000b113113b451010535555559575555557f58abfae76776767
000000000000000049494949bbbbbbbb00000000465555693b354b333b054b030000000000800b0a3b1bb131350101535b5ccbd87eecc9977777777776777767
000000000000000049494949bbbbbbbb0000000046555569b33334bbb00004bb0f000f0000b0b00b311311bbb510105b5b8ccbec7eecc9976666666676666667
000000006777677749494949bbbbbbbb77777777466666694b55233b4b55200b49f049f0b3bc3bb331b311314501066b7777777777777777feb8eb8a77777777
0000500000aaaa00494949490000000066666666465555693b33b53b3b00b50b49f049f054445444311b1bb13510166b5e555b557332e8877777777776666667
000090000a9999a04949494900000000666666664655596934bb35b434bb05b4ffffffff49494949b113113b35010154ae8c9bee7b5e29976666666676777767
00a999a0a9aaaa9a49494949000000006666666646555569eb45334beb45004b4444444449f949f93113b131e510105bae8c9bee75b2e887b5b2e8be76776767
00999990a9a00a9a4949494900000000660000664655556934b3353b34b0050b9999999947f747f73b1b11bb3501015b77777777777777777777777776767767
00777770a9a00a9a494949490000000040000004465555693b4395b43b4095b444444444ffafffafb11311313510105455a555c57cc66cc77777777776777767
00777770a9aaaa9a494949490000000040000004465555693b533b433b500b431220122047f747f731b31bb13501015338a99ac8766cc6677777777776666667
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
717ccc170000077777cc77cc000c000c8888888888887777117ccc1dcfcfcfcf1d6d6d1dcfcfcfcf14191941491941411888aaaccc99e7e1177c1c1771cc7771
617cc1160000000767c667c6000000004444444444444444d17cc1117c7c7c7cd1d6d6d17c7c7c7c141919414919441117787a7c7cbbee71117c1c1777ccc711
617ccc1600000070cc76cc7600000c004444444444444444117ccc1dc7c7c7c71d6d6d1dc7c7c7c7144999444999144118887a7cccb77ee11771111111111711
71cccc1700000700c667c6670c00c0004000000540000004d1cccc117c7c7c7cd1d6d6d17c7c7c7c111111111119111111111111111111111c1c777ccccc7771
71cccc170770077776cc76ccc00c0000400000054000000411cccc1dc7c7c7c71d6d6d1dc7c7c7c7000000001999100000000000000000001ccc717c1c1c7711
71ccc1170077000077cc77cc0000000c4000000540000004d1ccc1117c7c7c7cd1d6d6d17c7c7c7c000000001111100000000000000000001c1c777c1c1c7771
54cccc54700000005454545454545454400000054000000454cccc54545454545454545454545454000000000000000000000000000000001111111111111111
21cccc21070000002121212121212121400000054000000421cccc21212121212121212121212121000000000000000000000000000000000000000000000000
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
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000001
11111111111111111111111111111111111111111111111111111105550550050505550555055505050111111111111111111111111111111111111111111101
11111111111111111111111111111111111111111111111111111105050505005000500550005005550111111111111111111111111111111111111111111101
11111111111111111111111111111111111111111111111111111105550505050500500500005000050111111111111111111111111111111111111111111101
11111117111111111111111111111111111111111111111111111105050505050505550555005005550111111111111111111111111111111111111111111101
11111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000001
11111111111111111111111111111111111111111111111111111111111111111111111111111111111171111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111aaaa111
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111a9999a11
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111a9aaaa9a1
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111a9a11a9a1
11111111111111111111111111111171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111a9a11a9a1
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111a9aaaa9a1
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117111111111111a9999a11
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111aaaa111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111711111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
71111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111117111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111171111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111117111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117111bb
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111333311111bb
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133311111111333311111bb
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133311111111333311111bb
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133311111111333311111bb
111111111111111111111111111111111111111111111111111111111111111111111711111111111111111116666666665111111133311111111555533333bb
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111116666666665111111133333338888555533333bb
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111116666666665111111133333338888555533333bb
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111666666666511111113333333888833333333344
53311111111111111111111111111111111111115533331133111111111111111111111111111111111111111666666666513111113333333bbbb33333333344
53333311331111171111111111115533113311115533331133111bb53331111111111111111111111133333aa666666666aa9913113333333bbbb33333333344
33333311331111bbb533311111115533113311333333333388331bb5333111311b511111111111111133333aa666666666aa9913153333333bbbb333333333bb
33333333881553bbb533311113333333338811333333333388333bb3333311311b51131131b111111133333aa666666666aa998535bbb3333bbbb333355555bb
33333333885153bbb333333353333333338851333333333388553bb3333388533b33331131b55311113333338fffffffff43338533bbb33333333333355555bb
b3333333bb3333bbb33333330333bb3333883333bb333333bb33344b333388533b33338853b5531115333333bfffffffff4333b333bbb33333333333355555bb
b3333333bb3333444b3333333333bb3333bb3333bb333333bb33344b3333bb3334b3338853b3333883333333bfffffffff4333b33bbbb3333333333335555533
b4433333bb3335444b3333333505bb3333bb3385bb44bb333333344b3333bb3334b333bb3343333bb5bbbbbff777fff777ff44b35b444bbbb44445555bbbbb33
b44bbb33333330bbbb4443333050bb443333335bbb44bb3333335bbb4bb333355bb443bb35bbb33bb3bbbbbff777fff777ff44335b444bbbb44445555bbbbb33
033bbb33333335bbbb4443333500bb44333355bbbb44bb3344555bbb4bb333355bb44b3335bbbb3335bbbbbff777fff777ff44335b444bbbb44445555bbbbb33
533444bb44555b5050333bbb5bbb5033bb4455bb553344bb4455b333344b445bb3333b333b3bbb33354444444fffffffff434b45b3333bbbb4444555544444bb
533444bb44555b0555333bbb5bbb5533bb4455bb553344bb4455b333344b445bb33334445b3334b4454444444fffffffff434b45b3333bbbb3333555544444bb
533333bb505554bbb0333bbb54445033bb5055445b3333bb35554bb3333b33544b33333354b334b3343333333fffffffff433b3543333bbbb3333555544444bb
033333bb055554bbb5333bbb54440533bb005544453333bb35554bb3333b33544b33333354b333b3353333333544fff433333b3543333bbbb3333555544444bb
bbb33350505050444bbbb0505050bbbb50505b53bbbbbb333333444bbbb3333334bbbb333343333333bbbbbb3333fff43333bb333bbbb3333333333333333344
bbbbbb05550555444bbbb5055505bbbb55055535bbbbbb333333344bbbb3333334bbbb33334bbb3335bbbbbb3333fff4bbbbb3333bbbb3333333333333333344
5bbbbbbb5555525050bbbbbb522250bbbb505522bbbbbbbb55552333b44b5552233bb455523334b552444446666666666666555523bbb3333333333333333344
0bb444bb5555520005bbbbbb522205bbbb55552225bb44bb55552333b44b5552233bb455523334b5554444466666666666665555234443333333355553333344
5bb444bb55555b5050bbbbbb5bbb50bbbb5555225bbb44bb55552333b44b555bb53bb3333b5333b33b3333366666666666665555b3444bbbb555555552222233
5bb333bb55055b5555bbbbbb5bbb55bbbb0555bb55bb33bb3333b553b33b333bb53bb3333353334bb53366666666666666666665b3444bbbb555555552222233
5bb333bb5050505550444bbb505050bbbb5053bb53bb33bbbbbbb55bb334333335b443bbb35bb34bb3336666666666666666666533444bbbb555555552222233
b4433344bbbbb5555b444444b500bb4444bbbb44bb443344bbbb355b4334bbb335b443bbb33bb3b44533666666666666666666653b333bbbb555533332222233
b4433344bbbbb0555bbbb444b050bb4444bbbb5bbb443344bbbb355b433bbbb3334bbe4453344eb443ee6665b6666666665466653b333bbbb33333333bbbbb55
4bb333bb4455550554bbbbbb550544bbbbbb55b5bb44334444553334beeb4453334bbe445353334bb5ee6665466666666654666534333bbbb33333333bbbbb55
4bbeeebb4455505054bbbbbb505044bbbb44555444bbeebb44553334bee44453353bb3bb335333b44933666546666666665b666534333bbbb33333333bbbbb55
0bbeee44bb00055555bbb444050005bb4444355544bbeebbbb333553b334bb33353bb3bb395bb3b445336665b6666666665b6665333334444bbbbbbbb3333355
5bb33344bb50505550444444505050bb44bb535553bb3344bb333553b334bb3995b44344395bb3b553336665b6666666665b6665333334444bbbbbbbb3333355
5bb333bb440559555b444bbb5999bb44bbbb55b555bb3344bb33955b433b443995b4435533b443b55533666546666666665b66659beee4444bbbbbbbb3333355
b44333bb445059555b333bbb5999bb44bb44539953bb33444433955b433b44333b4333553534434bb533666549999999994466659beeebbbbbbbb55553333355
b44333bb550005bbb4333bbb05004433bb443599bb4433bb44339bb4333b55333b4333bb553bb35445336665599999999944666534eeebbbb444455553333333
433333bb555050bbb4333bbb50504433bb555050bb4433bb55553bb4333b553553b333bb533bb35443336665599999999943666534eeebbbb444455553333333
433333bb550555333b33344455554433bb555505443333bb55555bb43334bb5553b33344b33bb3000533333359999999999944535b333bbbb444455553333333
b3333344bb5555333b5554445555bb3344555555443333bbbb55533b3334bb5333b55344b000000000333333b9999999999944b55b3334444bbbb33333333333
b3333344bb5553333bbbb555aaaabb3344bb5555bb333344bb55533b333544b333b550000000000000333333b9999999999944b53b3334444bbbb33333333355
b333335544bbb3333bbbb555aaaabb5555bb5555bb333344bb55533b533544b0000000000000000000333333499999999999444b3b3334444bbbb33333333355
b55333554422200000bbb000aaaabb555544bb33bb33334444bb333b53300000000000000000000000000000499999999999444b00333bbbbbbbb33333333355
b55333000022200000bbb000bbbb00000044bb33bb55335544bb300000000000000000000000000000000000099999999999440000333bbbb444433339999955
00000000002220000b000000bbbb000000000000bb55335500000000000000000000000000000000000000000fff400fff40000000333bbbb444433339999955
0000000000bbb0000b000000bbbb0000000000000000000000000000000000000000000000000000000000000fff400fff40000000333bbbb444433339999955
0000000000bbb0000b00000033330000000000000000000000000000000000000000000000000000000000000fff400fff40000000333bbbb555533339999955
0000000000bbb0000b000bbb3333000000000000000000000000000000000000000000000000000000000000088820088820000000333bbbb555533333333355
0000000000bbb00003000bbb3333000000000000000000000000000000000000000000000000000000000000088820088820000000333bbbb5555333333333bb
bbbccccc33bbb00003000bbb000000000000000000000000000000000000000000000000000000000000000008882008882000000033344445555333333333bb
bbbccccc33bbb0000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000003334444bbbb555533333bb
bbbccccc33bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003334444bbbb55555555533
000ccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003334444bbbb55555555533
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033355554444bbbb5555533
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033355554444bbbb3333333
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055554444bbbb3333333
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444bbbb3333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333
000000000000000000000000000000000000000000000000000000000000000000000000000000bbbb0000000000000000000000000000000000000000000033
000000000000000000000000000000000000000000000000000000000000000000000000000000bbbb0000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000bbbb0000000aaaaaa000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000bbbb0000000aaaaaa00000000000000000000000000000000a
000000000000000000000000000000000000000000000000000000000000000000000000000000bbbb0000000aaaaaa00000000000000000000000000000000a
0000000000000000000000000000000000000000000000000000000000000000000000000bbbbbbbbb0000000aaaaaa00000000000008888888000000000000a
0000000000000000000000000000000000000000000000000000000000000000000000000bbbbb00000000000aaaaaa00000000000008888888000000000bb0a
0000000000000000000000000000000000000000000000000000000000000000000000000bbbbb00000000000aaaaaa00000000000008888888000000000bb0a
0000000000000000000000000000000000000000000000000000000000000000000000000bbbbb00000000000bbbbbb00000000000008888888000000000bb0a
0000000000000000000000000000000000000000000000000000000000000000000000000bbbbb00000000000bbbbbb00000000000008888888000000000bb0a
0000000000000000000000000000000000000000000000000000000000000000000000000bbbbb00000000000bbbbbb00000000000008888888000000000bb0b
00000000000000000000000000000000000000000000000000000000000000000000000003333300000000000bbbbbb00000000000008888888000000000bb0b
70000000000000000000000000000000000000000000000000000000000000000000007773333300000000000bbbbbb00000000000008888888000000000bb0b
77777700000000000000000000000000000000000000000000000000000000000000007773333300000000000bbbbbb0000000000000bbbbbbb000000000000b
7777770000000000000000000000000000000000000000000000000000000000007777777333330000bbbbbbbbbbbbb0000000000000bbbbbbb000000000000b
7777770000000000000000000000000000000000000000000000000000000000007777777333330000bbbbbbb3333330000000000000bbbbbbb000000000000b
7777770000000000000000000000000000000000000000000000000000000077777777777333330000bbbbbbb333333bbbbbb0000000bbbbbbb0000000bb0003
7777770000000000000000000000000000000000000000000000000000066677777777777000000000bbbbbbb333333bbbbbb0000000bbbbbbb0000000bb00b3
0777770000000000000000000000000000000000000000000000000000066677777777000000000000bbbbbbb333333bbbbbb3333333bbbbbbb0000000bb00b3
0000000000000000000000000000000000000000000000000000000000066677777777000000000000bbbbbbb333333bbbbbb3333333bbbbbbb0000000bb00b3
00000000000000000000000000000000000000000000000000000000000666777700000000000000000000000333333bbbbbb3333333bbbbbbb0000000bb00b3
00000000000000000000000000000000000000000000000000000777777666777700000000000000000000000000000bbbbbb3333333bbbbbbb0000000bb00b3
00000000000000000000000000000000000000000000000000000777777666777700000000000000000000000000000bbbbbb3333333bbbbbbbcccccccbb00b3
000000000000000000000000000000000000000000000000077777777776660000000000000000000000000000000000000003333333bbbbbbbccccccc3300b0
000000000000000000000000000000000000000000000000077777777770000000000000000000000000000000000000000003333333bbbbbbbccccccc330000
000000000000000000000000000000000000000000007777777777777770000000000000000000000000000000000000000000000000bbbbbbbccccccc330000
000000000000000000000000000000000000000000007777777777777770000000000000000000000000000000000000000000000000bbbbbbbccccccc330000
0000000000000000000000000000000000000000000077777777777777700000000000000000000000000000000000000000000000000000000ccccccc330000
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
0a0000002f0024242424002f00000000000000000000000267000001010000000000010100000108000000004300000000000000420000000000433b0008000a0a00000009000009000009000009000000000000000000000000000000000000000000003b003a00000000002a00000000000000000000003b2b002a0000000a
0a0000000202020202020202000021000000000000000002010000010100003a000001010000010000000000420000000000000040000000000042000008000a0a00000000000000000000000000000000000000000000000000000000000000002a3a2b00002a003a003a0000003a2b2b3b002b003a002a003a003a3a00000a
0a00000002242424242424020000000000000000000000050100000101002b3a3b0001010000010000000000400000000000000042000000000042000008000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a
__sfx__
000300000913109131091310a1310e141111511414119141201412115121161171710d1710d1710d1710f1710f17115171181611c151211512216122171171710d1710c1710c1710c1710c171001010010100101
00040000111110d1210a1510a1510a1410a1010c1010f101191111b1411d1711e1712110120101181010110100101001010010100101001010010100101001010010100101001010010100101001010010100101
010300000e1310e1510e1710e17114101131011a1010c1510b15109131081210e1010010100101001010010100101001010010100101001010010100101001010010100101001010010100101001010010100101
010500000f1510f151101511015113101111511d1511e1511e1511f1012115121151211512010120151201512015117101161510e1510c1510c1510c151000010000100001000010000100001000010000100001
01030000125401254019540195401d5401d5402354024540275402753127521275212752127511275112751127511275112750127501275012750127501275012750127501275012750127501275012750127501
001400000517001170011000510006100111001010011100111001110011100101000e10000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
01100010177541775217755177522375423752237552375222754227522275522752207542075220755207522270022700227002270021700207001e7001d7002070020700207002070000704007040070400704
01240010177541775217755177522375423752237552375222754227522275522752207542075220755207522270022700227002270021700207001e7001d7002070020700207002070000000000000000000000
__music__
03 07464040
03 06404040
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
