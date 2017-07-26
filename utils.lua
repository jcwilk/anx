-- START LIB
function ceil(n)
  return -flr(-n)
end

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
  return (((angle-player.bearing)+.5).val-.5)/field_of_view*64*2+64
end

function screenx_to_angle(screenx)
  local angle_offset=(screenx/127-.5)*field_of_view

  return player.bearing+angle_offset
end
-- END LIB