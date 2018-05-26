local searchRange = 1000 --Max search range

local term = require("term")
local component = require("component")
local color = require("color")
local modem = component.modem
local event = require("event")
local write = term.write
local read = io.read

local running = true
local foundBlocks = {}
local currentList = 0
local isRemote = false

local function openPort()
local myPort = 1
while modem.isOpen(myPort) do
if myPort == 65535 then
io.stderr.print("no more ports available")
else
myPort = myPort + 1
end
end
if modem.open(myPort) then
write("Income port is ["..myPort.."]")
else
io.stderr.print("problem with port opening")
end
end

local function closePort(port)
modem.close(port)
end

local function link()
local alone = true
while alone do
local _, _, addrs, gotPort, _, message = event.pull("modem_message")
if message ~= "hola mi amigo" then
modem.send(addrs, gotPort, "you're not my amigo!")
else
alone = false
end
end
return addrs, gotPort
end

local function readNumber(name, validator)
local index
while not index do
write(name.."> ")
index = tonumber(read())
if not index or validator and not validator(index) then
index = nil
write("Err:Invalid Input\n")
end
end
return index
end

local params = {
{ "Switch visibility",
function()
if readNumber("1.On\n2.Off\nAnswer", function(x) return x == 1 or x == 2 end) == 1 then
for i = 1, #foundBlocks[currentList] do
foundBlocks[currentList][i][2]["setVisible"](true)
end
else
for i = 1, #foundBlocks[currentList] do
foundBlocks[currentList][i][2]["setVisible"](false)
end
end
end
},
{ "Set Color",
function()
local stopper = true
write("Enter color in html format(#rrggbb)\nColor> ")
local clr = read()
while stopper do
if (string.len(clr) == 7) and (string.sub(clr, 1, 1) == "#") then
clr = "0x"..string.sub(clr, 2)
stopper = false
elseif clr == "exit" or clr == "stop" or clr == "back" then
clr = nil
stopper = false
else
clr = readNumber("Err:Invalid Input\nTry agan")
end
end
if clr ~= nil then
clr_r, clr_g, clr_b = color.integerToRGB(clr)
for i = 1, #foundBlocks[currentList] do
foundBlocks[currentList][i][2]["setColor"](clr_r / 255, clr_g / 255, clr_b / 255)
end
end
end
},
{ "Set Alpha",
function()
local alpha = readNumber("Enter number from 0 to 1\nAlpha", function(x) return x >= 0 and x <= 1 end)
if alpha ~= nil then
for i = 1, #foundBlocks[currentList] do
foundBlocks[currentList][i][2]["setAlpha"](alpha)
end
end
end
},
{ "Delete",
function()
table.remove(foundBlocks, currentList)
end
},
{ "Back",
function()
end
}
}

local commands = {
{ "Check connection",
function()
write("Connected Players: "..component.glasses.getBindPlayers())
end
},
{ "Host remote access",
function()
if isRemote then
closePort(myPort)
myPort = 1
write = term.write
read = io.read
else
openPort()
local con_ip, con_port = link()
write = function(text)
component.modem.send(con_ip, con_port, text)
end
read = function()
local _, _, _, _, _, msg = event.pull("modem_message")
return msg
end
end
end
},
{ "Search",
function()
write("BlockID> ")
local blockID = read()
local range = readNumber("Range", function(x) return x > 0 and x <= searchRange end)
positions = component.sensor.search(blockID, -1, "", range)
if #positions == 0 or positions == nil then
write("Search - found nothing {"..blockID.."}")
else
if foundBlocks[1] == nil then
foundBlocks[1] = {{}}
foundBlocks[1][1][3] = blockID
for i = 1, #positions do
if foundBlocks[1][i] == nil then
foundBlocks[1][i] = {}
end
foundBlocks[1][i][1] = positions[i]
foundBlocks[1][i][2] = component.glasses.addCube3D()
foundBlocks[1][i][2]["set3DPos"](positions[i].x,positions[i].y,positions[i].z+3)
foundBlocks[1][i][2]["setVisibleThroughObjects"](true)
end
else
for i = 1, #foundBlocks do

if foundBlocks[i][1][3] == blockID then
for a = 1, #foundBlocks[i] do
for b = 1, #positions do
if foundBlocks[i][a][1] == positions[b] then
table.remove(positions, b)
end
end
end
end
for a = 1, #positions do
if foundBlocks[1][#foundBlocks[i]+a] == nil then
foundBlocks[i][#foundBlocks[i]+a] = {}
end
foundBlocks[i][#foundBlocks[i]+a][1] = positions[a]
foundBlocks[i][#foundBlocks[i]+a][2] = component.glasses.addCube3D()
foundBlocks[i][#foundBlocks[i]+a][2]["set3DPos"](positions[i].x,positions[i].y,positions[i].z+3)
foundBlocks[i][#foundBlocks[i]+a][2]["setVisibleThroughObjects"](true)
end
end
end
end
write("found "..#positions.." {"..blockID.."}")
end
},
{ "List",
function()
if foundBlocks[1][1][3] == nil then
write("Search list is empty")
else
for i = 1, #foundBlocks do
write(i.."."..foundBlocks[i][1][3].."\n")
end
currentList = readNumber("Input", function(x) return x > 0 and x <= #foundBlocks end)
for i = 1, #params do
write(i.."."..params[i][1].."\n")
end
params[readNumber("Input", function(x) return x > 0 and x <= #params end)][2]()
end
end
},
{ "Exit",
function()
running = false
for a = 1, #foundBlocks do
for b = 1, #foundBlocks[a] do
component.glasses.removeObject(foundBlocks[a][b][2].getID())
end
end
end
}
}

local function main()
while running do
for i = 1, #commands do
write(i.."."..commands[i][1].."\n")
end
commands[readNumber("Input", function(x) return x > 0 and x <= #commands end)][2]()
read()
term.clear()
end
end

local result, reason = pcall(main)
if not result then
write(reason.."\n")
end
