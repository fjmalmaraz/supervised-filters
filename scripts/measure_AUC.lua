local xe = require 'xemsg'
xe.NN_POLLIN = 1
xe.NN_POLLOUT = 1

local px = require "parxe"

local predicted1 = assert(arg[1], "Needs a CSV predicted file as first argument")
local predicted2 = arg[2]
local test_csv = arg[3] or "answer_key.csv"
if predicted2 == "nil" then predicted2 = nil end
if test_csv == "nil" then test_csv = nil end

local SUBJECTS = {"Dog_1","Dog_2","Dog_3","Dog_4","Dog_5","Patient_1","Patient_2"}
local REPETITIONS = 1000
local seed  = 987654
local ratio = 0.6 -- test ratio (validation is 1 - ratio)

local function build_subjects_metric()
  local subjects_ROC = {}
  for i,k in ipairs(SUBJECTS) do
    subjects_ROC[i] = metrics.roc()
  end
  return subjects_ROC
end

-- Receives CSV filename and returns a matrix with its values and the keys
-- table.
local function load_matrix(csv_filename, keys_order)
  local keys_order = keys_order or {}
  local p = april_assert(io.open(csv_filename), "Unable to open %s", csv_filename)
  p:read("*l")
  local p_table = {}
  for i,p_line in iterator(p:lines()):enumerate() do
    local p_key,p_value = table.unpack(p_line:tokenize(","))
    assert(not keys_order[i] or keys_order[i] == p_key,
           "Keys should be in same order as in test CSV file")
    keys_order[i] = p_key
    p_table[#p_table+1] = tonumber(p_value)
  end
  return matrix(p_table),keys_order -- matrix(t_table),matrix(subjects)
end

local function build_subjects_indices(keys_order)
  local subjects = {}
  for i,key in ipairs(keys_order) do
    local subject_type,n = key:match("^([^_]+)_([0-9]+)")
    n = tonumber(n)
    if subject_type == "Patient" then n = n + #SUBJECTS - 2 end
    subjects[#subjects+1] = n
  end
  return matrix(subjects)
end

-----------------------------------------------------------------------------

local t,keys_order = load_matrix(test_csv)
local p1 = load_matrix(predicted1, keys_order)
local p2 = predicted2 and load_matrix(predicted2, keys_order)
local subjects = build_subjects_indices(keys_order)

do
  local N = subjects:size()
  local rnd  = random(seed)
  local shuf = matrixInt32(rnd:shuffle(N))
  t  = t:index(1, shuf)
  p1 = p1:index(1, shuf)
  p2 = p2 and p2:index(1, shuf)
  subjects = subjects:index(1, shuf)
end

local test_val
do
  local N = subjects:size()
  local wall = math.round(N*ratio)
  local test_slice = {1,wall}
  local val_slice  = {wall+1, N}
  function test_val(m)
    return m[{test_slice}],m[{val_slice}]
  end
end

local t_test,t_val = test_val(t)
local p1_test,p1_val = test_val(p1)
local subjects_test,subjects_val = test_val(subjects)
local p2_test,p2_val
if predicted2 then p2_test,p2_val = test_val(p2) end

local function compute_AUC_bootstrap(t, p1, p2, ...)
  print("# Number of samples: ", t:size())
  local boot_sample = px.boot{
    size = t:size(),
    R = REPETITIONS,
    k = predicted2 and 3 or 1,
    statistic = function(idx)
      local p1 = p1:index(1,idx)
      local t = t:index(1,idx)
      local a1,a2,diff
      a1 = metrics.roc(p1,t):compute_area()
      if predicted2 then
        local p2 = p2:index(1,idx)
        a2 = metrics.roc(p2,t):compute_area()
        diff = a1 - a2
        return a1,a2,diff
      else
        return a1
      end
    end,
    seed = 1234,
    verbose = util.stdout_is_a_terminal(),
  }
  return boot_sample,t,p1,p2,...
end

local function show_AUC_per_subject(t, p, subj_idx, prefix)
  for i,k in pairs(SUBJECTS) do
    local idx = subj_idx:eq(i):to_index()
    if #idx > 0 then
      local roc = metrics.roc(p:index(1,idx), t:index(1,idx))
      print("# %s %s AUC :: "%{prefix,k}, roc:compute_area())
    end
  end
end

local function print_bootstrap(sufix, boot_sample, t, p1, p2, subj_idx)
  show_AUC_per_subject(t, p1, subj_idx, "P1")
  if predicted2 then
    local r1 = metrics.roc(p1,t)
    local r2 = metrics.roc(p2,t)
    print("# AUC P1", sufix)
    print(sufix .. "_P1_AUC= ", r1:compute_area())
    print(sufix .. "_P1_CI= ", stats.boot.ci(boot_sample, 0.95, 1))
    --
    show_AUC_per_subject(t, p2, subj_idx, "P2")
    print("# AUC P2", sufix)
    print(sufix .. "_P2_AUC= ", r2:compute_area())
    print(sufix .. "_P2_CI= ", stats.boot.ci(boot_sample, 0.95, 2))
    --
    print("# AUC P1 - P2", sufix)
    print(sufix .. "_P1_P2_CI= ", stats.boot.ci(boot_sample, 0.95, 3))
    print("# p-value P1 - P2", sufix)
    print("p-value= ", metrics.roc.test(r1, r2, { method="delong" }):pvalue())
  else
    print("# AUC", sufix)
    print(sufix .. "_P1_AUC= ", metrics.roc(p1,t):compute_area())
    print(sufix .. "_P1_CI= ", stats.boot.ci(boot_sample, 0.95))
  end
end

print_bootstrap("VAL", compute_AUC_bootstrap(t_val, p1_val, p2_val, subjects_val))
print_bootstrap("TEST", compute_AUC_bootstrap(t_test, p1_test, p2_test, subjects_test))
