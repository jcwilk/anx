-- START LIB
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
  panic_attack_duration = 500
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

  --debug=true
  -- menuitem(3, "debug", function()
  --   if debug then
  --     debug = false
  --   else
  --     debug = true
  --   end
  -- end)



  local unfreeze_mobs_menu, freeze_mobs_menu

  function freeze_mobs_menu()
    freeze_mobs = true
    menuitem(4, "unfreeze mobs", unfreeze_mobs_menu)
  end

  function unfreeze_mobs_menu()
    freeze_mobs = false
    menuitem(4, "freeze mobs", freeze_mobs_menu)
  end

  --uncomment for development
  --unfreeze_mobs_menu()

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
  delays = makedelays(300) --max of 10 second delay

  field_of_view=orig_field_of_view -- 45*
  draw_distance=orig_draw_distance
  height_ratio=orig_height_ratio
  turn_amount=orig_turn_amount
  speed = orig_speed
  is_panic_attack = false
  is_insane = false

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

  failed_blip_delaying=false

  music(-1)
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

  if is_panic_attack then
    music(0,1000)
  end

  is_panic_attack = false

  if current_anxiety >= 0 then
    current_anxiety-=.05+.005*current_anxiety
    if is_insane and current_anxiety < anxiety_insanity_start then
      is_insane = false
      music(-1,1000)
    end

    if current_anxiety < 0 then
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

downscale_anxiety = .4 --sliding scale for how intense to make it
function anxiety_factor_at(anxiety_level)
  -- https://www.desmos.com/calculator/zocublzy4s
  return 1/(anxiety_level*downscale_anxiety/2+1)
end

anxiety_insanity_start=10
anxiety_factor_insanity_start=anxiety_factor_at(anxiety_insanity_start)
function recalc_settings()
  local anxiety_diff = current_anxiety - visual_anxiety
  local max_diff = max(abs(anxiety_diff/10),max_anxiety_diff)
  visual_anxiety+= mid(-max_anxiety_diff,anxiety_diff,max_anxiety_diff)

  local anxiety_factor = anxiety_factor_at(visual_anxiety)

  fisheye_ratio = (1 - anxiety_factor) * 3
  --field_of_view = orig_field_of_view / anxiety_factor
  height_ratio = .44+.08*abs(sin(walking_step))+.15*anxiety_factor
  draw_distance = orig_draw_distance * (1/4 + 3/4*anxiety_factor)
  turn_amount = orig_turn_amount * (2 - anxiety_factor)

  speed = orig_speed * (2 - anxiety_factor)

  local insanity_gap = 1-anxiety_factor_insanity_start
  anxiety_vertical_offsets_scalar = max(0,1 - anxiety_factor - insanity_gap)/anxiety_factor_insanity_start
end

function add_anxiety()
  current_anxiety+=3

  if (not is_insane) and current_anxiety >= anxiety_insanity_start then
    music(0)
    is_insane = true
  end

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
-- END LIB
