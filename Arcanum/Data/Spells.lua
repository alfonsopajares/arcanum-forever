local _, addon = ...

-- Ranks are ordered from lowest to highest. Candidates are never shown just
-- because they exist in this catalog: the player's learned spells are checked.
addon.spells = {
    { category = "buffs", ranks = {1459,1460,1461,10156,10157}, friendly = true },
    { category = "buffs", ranks = {23028}, friendly = true, reagent = 17020 },
    { category = "buffs", ranks = {604,8450,8451,10173,10174}, friendly = true },
    { category = "buffs", ranks = {1008,8455,10169,10170}, friendly = true },
    { category = "armor", ranks = {168,7300,7301}, self = true },
    { category = "armor", ranks = {7302,7320,10219,10220}, self = true },
    { category = "armor", ranks = {6117,22782,22783}, self = true },
    { category = "teleports", ranks = {3561}, self = true, reagent = 17031 },
    { category = "teleports", ranks = {3562}, self = true, reagent = 17031 },
    { category = "teleports", ranks = {3563}, self = true, reagent = 17031 },
    { category = "teleports", ranks = {3565}, self = true, reagent = 17031 },
    { category = "teleports", ranks = {3566}, self = true, reagent = 17031 },
    { category = "teleports", ranks = {3567}, self = true, reagent = 17031 },
    { category = "portals", ranks = {10059}, reagent = 17032 },
    { category = "portals", ranks = {11416}, reagent = 17032 },
    { category = "portals", ranks = {11417}, reagent = 17032 },
    { category = "portals", ranks = {11418}, reagent = 17032 },
    { category = "portals", ranks = {11419}, reagent = 17032 },
    { category = "portals", ranks = {11420}, reagent = 17032 },
    { category = "mana", ranks = {12051}, self = true },
    { category = "mana", ranks = {759}, item = 5514, self = true },
    { category = "mana", ranks = {3552}, item = 5513, self = true },
    { category = "mana", ranks = {10053}, item = 8007, self = true },
    { category = "mana", ranks = {10054}, item = 8008, self = true },
    { category = "refreshments", ranks = {5504,5505,5506,6127,10138,10139,10140},
      items = {5350,2288,2136,3772,8077,8078,8079}, kind = "water", levels = {1,5,15,25,35,45,55}, self = true },
    { category = "refreshments", ranks = {587,597,990,6129,10144,10145,28612},
      items = {5349,1113,1114,1487,8075,8076,22895}, kind = "food", levels = {1,5,15,25,35,45,55}, self = true },
    { category = "defenses", ranks = {12472}, self = true }, -- Cold Snap (Forever/vanilla ID)
    { category = "defenses", ranks = {11958}, self = true }, -- Ice Block (Forever/vanilla ID)
    { category = "defenses", ranks = {11426,13031,13032,13033}, self = true },
    { category = "defenses", ranks = {1463,8494,8495,10191,10192,10193}, self = true },
    { category = "defenses", ranks = {543,8457,8458,10223,10225}, self = true },
    { category = "defenses", ranks = {6143,8461,8462,10177,28609}, self = true },
    { category = "utility", ranks = {118,12824,12825,12826} },
    { category = "utility", ranks = {28271}, discoverRanks = false }, -- Turtle
    { category = "utility", ranks = {28272}, discoverRanks = false }, -- Pig
    { category = "utility", ranks = {475}, friendly = true },
    { category = "utility", ranks = {2855} },
    { category = "utility", ranks = {1953}, self = true },
    { category = "utility", ranks = {2139} },
    { category = "utility", ranks = {122,865,6131,10230}, self = true },
    { category = "utility", ranks = {130}, friendly = true, reagent = 17056 },
}
