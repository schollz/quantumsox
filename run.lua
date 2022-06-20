WORKDIR="/tmp/"
debugging=true

local os_capture=function(cmd,raw)
  local f=assert(io.popen(cmd,'r'))
  local s=assert(f:read('*a'))
  f:close()
  if raw then return s end
  s=string.gsub(s,'^%s+','')
  s=string.gsub(s,'%s+$','')
  s=string.gsub(s,'[\n\r]+',' ')
  return s
end

function os.cmd(cmd)
  if debugging then
    print(cmd)
  end
  os.execute(cmd.." 2>&1")
end

function math.round(number, quant)
  if quant == 0 then
    return number
  else
    return math.floor(number/(quant or 1) + 0.5) * (quant or 1)
  end
end



function os.capture(cmd,raw)
  local f=assert(io.popen(cmd,'r'))
  local s=assert(f:read('*a'))
  f:close()
  if raw then return s end
  s=string.gsub(s,'^%s+','')
  s=string.gsub(s,'%s+$','')
  s=string.gsub(s,'[\n\r]+',' ')
  return s
end


-- qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890
local charset={}
for i=48,57 do table.insert(charset,string.char(i)) end
for i=65,90 do table.insert(charset,string.char(i)) end
for i=97,122 do table.insert(charset,string.char(i)) end

function string.random(length)
  if length>0 then
    return string.random(length-1)..charset[math.random(1,#charset)]
  else
    return ""
  end
end

function string.random_filename(suffix,prefix)
  suffix=suffix or ".wav"
  prefix=prefix or WORKDIR.."quantumsox-"
  return prefix..string.random(8)..suffix
end

local audio={}

function audio.get_info(fname)
  local sample_rate=tonumber(os.capture("sox --i "..fname.." | grep 'Sample Rate' | awk '{print $4}'"))
  local channels=tonumber(os.capture("sox --i "..fname.." | grep 'Channels' | awk '{print $3}'"))
  return sample_rate,channels
end

function audio.silence_add(fname,silence_length)
  local sample_rate,channels=audio.get_info(fname)
  local silence_file=string.random_filename()
  local fname2=string.random_filename()
  -- first create the silence
  os.cmd("sox -n -r "..sample_rate.." -c "..channels.." "..silence_file.." trim 0.0 "..silence_length)
  -- combine with original file
  os.cmd("sox "..fname.." "..silence_file.." "..fname2)
  os.cmd("rm -f "..silence_file)
  return fname2
end

function audio.join(fnames)
  local fname2=string.random_filename()
  os.cmd(string.format("sox %s %s",table.concat(fnames," "),fname2))
  return fname2
end


function audio.trim(fname,start,finish)
  local fname2=string.random_filename()
  if finish==nil then
    os.cmd("sox "..fname.." "..fname2.." trim "..start)
  else
    os.cmd("sox "..fname.." "..fname2.." trim "..start.." "..finish-start)
  end
  return fname2
end


function shift(fname,s,e,w)
  local part1=audio.trim(fname,0,s)
  local part2=audio.trim(fname,s,e)
  local part3=audio.trim(fname,e)
  local part1_silence=audio.silence_add(part1,e-s)
  local part_silent=audio.join({part1_silence,part3})

  local part1_new=audio.trim(part_silent,0,s+w)
  local part3_new=audio.trim(part_silent,e+w)
  local part_new=audio.join({part1_new,part2,part3_new})
  return part_new
end

function quantize(fname,fnameout,bpm)
  local foo=os_capture("aubioonset -i "..fname.." -t 1 -s -60 -M "..60/bpm/4,true)
  local breaks={}
  for line in string.gmatch(foo,"(.-)\n") do
    local num=tonumber(line)
    if num~=nil then
      table.insert(breaks,num)
    end
  end

  for i,_ in ipairs(breaks) do
    if i>1 then
      local v1=breaks[i-1]
      local v2=breaks[i]
      local w=math.round(v1,60/bpm/2)-v1
      print(v1,v2,w)
      if (v1+w)>0 then
        fname=shift(fname,v1-0.002,v1+(v2-v1)*0.8,w)
      end
    end
  end
  os.cmd("cp "..fname.." "..fnameout)
  os.cmd("rm -rf /tmp/quantumsox*")
end

quantize("marimba_bpm120_2.wav","2.wav",120)
