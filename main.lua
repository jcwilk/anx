-- START LIB
field_of_view=1/8 -- 45*
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
  max_width=0
  while screenx<=127 do
    behind_time=stat(1)-(start_time+screenx/127*alotted_time-buffer_time)
    draw_width=128*behind_time/alotted_time
    draw_width=flr(mid(1,10,draw_width))
    max_width=max(max_width,draw_width)
    skipped_columns+=draw_width-1

    angle_offset=((screenx+(draw_width-1)/2)/127-.5)*field_of_view

    pv=(player.bearing+angle_offset):tovector()
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
      if sprite_id > 0 then
        if band(fget(sprite_id),1) == 0 then
          found=true
        end
        pixel_col=flr(((intx+inty)%1)*8)
        if reversed then
          pixel_col=7-pixel_col
        end
        add(draw_stack,deferred_wall_draw(intx,inty,sprite_id,pixel_col))
      end
      if not debug then
        if (not found) and mob_pos_map[currx] and mob_pos_map[currx][curry] then
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
    end

    for stack_i=#draw_stack,1,-1 do
      draw_stack[stack_i]()
    end

    if draw_width>1 then
      line(screenx+1,127,screenx+draw_width-1,127,8)
    end

    screenx+=draw_width
  end
  color(12)
  print(1-skipped_columns/128)
  print(max_width)
end

mobile_pool = make_pool()
wall_pool = make_pool()
player =makemobile(false,makevec2d(8.3,-2.5),makeangle(-1/4))
for i=0,5 do
  mobile_pool.make(makemobile(i%2,makevec2d(i+1,-(i%3)-1),makeangle(rnd())))
end
--mobile_pool.make()
--mob=makemobile(0,makevec2d(7,-2),makeangle(-1/8))
--mobile_pool.make(makemobile(1,makevec2d(4,-4),makeangle(rnd())))

menuitem(1, "debug", function()
  if debug then
    debug = false
  else
    debug = true
  end
end)

function _update()
  local offset = makevec2d(0,0)
  local facing = player.bearing:tovector()
  local right = makevec2d(facing.y,-facing.x)
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
  end
  if btn(3) then
    offset-=facing
  end
  if btn(4) then
    offset-=right
  end
  if btn(5) then
    offset+=right
  end
  local hitbox_radius=0.5
  local new_coords=player.coords+offset*0.1
  --todo - this code is ugly af
  local door_found=false
  for checkx=round(new_coords.x-hitbox_radius),round(new_coords.x+hitbox_radius) do
    for checky=round(player.coords.y-hitbox_radius),round(player.coords.y+hitbox_radius) do
      sprite_id = mget(checkx,-checky)
      if (not door_found) and sprite_id > 0 then
        if fget(sprite_id,1) then
          door_found=mget(checkx+tounit(offset.x),-checky)
          new_coords.x=checkx+2.5*tounit(offset.x)
          new_coords.y=checky
        else
          new_coords.x=player.coords.x
        end
      end
    end
  end
  for checkx=round(player.coords.x-hitbox_radius),round(player.coords.x+hitbox_radius) do
    for checky=round(new_coords.y-hitbox_radius),round(new_coords.y+hitbox_radius) do
      sprite_id = mget(checkx,-checky)
      if (not door_found) and sprite_id > 0 then
        if fget(sprite_id,1) then
          door_found=mget(checkx,-checky-tounit(offset.y))
          new_coords.x=checkx
          new_coords.y=checky+2.5*tounit(offset.y)
        else
          new_coords.y=player.coords.y
        end
      end
    end
  end

  if door_found == 11 then
    sky_color=1
    ground_color=3
  elseif door_found == 5 then
    sky_color=7
    ground_color=2
  end

  if player.coords.x != new_coords.x or player.coords.y != new_coords.y then
    changed_position=true
    player.coords=new_coords
  end

  mobile_pool:each(function(m)
    m.bearing+=.01
    --m:turn_towards_player()
  end)
end

function draw_stars()
  local x,y,angle
  color(7)
  angle=player.bearing-1/16
  local init=flr(angle.val*100)
  local final=flr((angle.val+1/8)*100)
  for i=init,final do
    pset((i-init)/100*8*128,((i*19)%64))
  end
end

function sort_by_distance(m)
  return (m.coords-player.coords):diamond_distance()
end

mob_pos_map={}
sky_color=7
ground_color=2
fog_color=1
function _draw()
  rectfill(0,0,127,63,sky_color)
  rectfill(0,64,127,127,ground_color)
  local fog_height=height_scale*2/draw_distance/field_of_view
  rectfill(0,64-fog_height*(1-height_ratio),127,64+fog_height*height_ratio,fog_color)
  --draw_stars()
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
  color(12)
  cursor(0,0)
  print(start_time)
  print(stat(1))
  print("x"..player.coords.x.." y"..player.coords.y)
end
-- END LIB
