require "import"
import "com.androlua.Http"
import "android.widget.Toast"
import "android.app.AlertDialog"
import "android.view.WindowManager"
import "android.os.Handler"
import "android.os.Looper"
import "java.io.File"

local updateURL = "https://raw.githubusercontent.com/csrusefulresources-collab/Digital-Text-to-Audio-GENERATE/main/version.txt"
local downloadURL = "https://raw.githubusercontent.com/csrusefulresources-collab/Digital-Text-to-Audio-GENERATE/main/main.lua"
local currentVersion = "1.0"
local currentDir = "/storage/emulated/0/解说/Plugins/Digital Text to Audio GENERATE"
local oldPath = currentDir .. "/old_main.lua"
local mainPath = currentDir .. "/main.lua"

local mainDialog = nil

local function runOriginalCode()
    if File(oldPath).exists() then
        local func, err = loadfile(oldPath)
        if func then pcall(func) end
    end
end

local function checkUpdate()
    Http.get(updateURL, function(code, response)
        if code == 200 and response then
            local onlineVersion = tostring(response):gsub("^%s*(.-)%s*$", "%1")
            if onlineVersion ~= currentVersion then
                Handler(Looper.getMainLooper()).post(Runnable{run=function()
                    local updateAlertDlg = AlertDialog.Builder(service or activity)
                    updateAlertDlg.setTitle("Update Available!")
                    updateAlertDlg.setMessage("New version " .. onlineVersion .. " is ready. Your current version is " .. currentVersion)
                    updateAlertDlg.setPositiveButton("Update Now", {onClick=function(v)
                        v.dismiss()
                        Toast.makeText(service, "Downloading...", 0).show()
                        Http.get(downloadURL, function(c, content)
                            if c == 200 and content then
                                local f = io.open(oldPath, "w")
                                if f then f:write(content):close() end
                                
                                local mf = io.open(mainPath, "r")
                                if mf then
                                    local mainContent = mf:read("*a")
                                    mf:close()
                                    local newMainContent = mainContent:gsub('local currentVersion = ".-"', 'local currentVersion = "'..onlineVersion..'"')
                                    local mf2 = io.open(mainPath, "w")
                                    if mf2 then mf2:write(newMainContent):close() end
                                end
                                
                                local successDialog = AlertDialog.Builder(service or activity)
                                successDialog.setTitle("Update Successful")
                                successDialog.setMessage("Plugin updated to "..onlineVersion..". Restarting...")
                                successDialog.setPositiveButton("OK", {onClick=function(v2)
                                    v2.dismiss()
                                    if mainDialog then
                                        mainDialog.dismiss()
                                    end
                                    Handler(Looper.getMainLooper()).postDelayed(Runnable{run=function()
                                        local func, err = loadfile(mainPath)
                                        if func then
                                            pcall(func)
                                        else
                                            Toast.makeText(service, "Error loading updated plugin: " .. tostring(err), Toast.LENGTH_LONG).show()
                                        end
                                    end}, 1000)
                                end})
                                local d2 = successDialog.create()
                                d2.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
                                d2.show()
                            end
                        end)
                    end})
                    updateAlertDlg.setNegativeButton("Later", nil)
                    local d1 = updateAlertDlg.create()
                    d1.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
                    d1.show()
                end})
            end
        end
    end)
end

runOriginalCode()

Handler(Looper.getMainLooper()).postDelayed(Runnable{run=function()
    checkUpdate()
end}, 3000)