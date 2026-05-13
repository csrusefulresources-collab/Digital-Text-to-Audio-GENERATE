require "import"
import "android.app.AlertDialog"
import "android.widget.*"
import "android.view.WindowManager"
import "android.view.View"
import "android.media.MediaPlayer"
import "java.net.URLEncoder"
import "java.io.File"
import "android.os.Environment"
import "android.content.Intent"
import "android.net.Uri"
import "com.androlua.Http"
import "java.lang.String"
import "android.text.TextWatcher"

-- ==========================================
-- ⚙️ Configuration & Data Management
-- ==========================================
local tts_api_url = "https://openai-tts.schoolofmindlight.workers.dev/"
local voices_list = {"alloy", "echo", "fable", "onyx", "nova", "shimmer"}
local tones_list = {"Normal", "Professional", "Cheerful", "Serious", "Excited", "Sad", "Whispering", "Slow", "Fast"}
local mediaPlayer = nil

local prefs_path = tostring(service.getExternalFilesDir(nil)) .. "/tts_voice_prefs.txt"

local function loadSavedVoiceIndex()
    local file = io.open(prefs_path, "r")
    if file then
        local index = tonumber(file:read("*a"))
        file:close()
        return index or 0
    end
    return 0
end

local function saveVoiceIndex(index)
    local file = io.open(prefs_path, "w")
    if file then
        file:write(tostring(index))
        file:close()
    end
end

-- ==========================================
-- 1. Audio Controls & Logic
-- ==========================================
local function stopAudio()
    if mediaPlayer ~= nil then
        if mediaPlayer.isPlaying() then
            mediaPlayer.stop()
        end
        mediaPlayer.release()
        mediaPlayer = nil
    end
end

local function resetToGenerateState()
    stopAudio()
    if btnGenerate then btnGenerate.setText("Generate") end
    if btnDownload then btnDownload.setVisibility(View.GONE) end
end

local function applyTone(text, tone_hint)
    local modified_text = text
    if tone_hint == "Professional" then modified_text = "[Speak in a highly professional and articulate tone] " .. text
    elseif tone_hint == "Cheerful" then modified_text = "[Speak with a cheerful, upbeat, and happy tone] " .. text
    elseif tone_hint == "Serious" then modified_text = "[Speak with a very serious and formal tone] " .. text
    elseif tone_hint == "Excited" then modified_text = "[Speak with extreme excitement and enthusiasm] " .. text
    elseif tone_hint == "Sad" then modified_text = "[Speak with a sad and melancholic tone] " .. text
    elseif tone_hint == "Whispering" then modified_text = "[Whisper softly] " .. text
    elseif tone_hint == "Slow" then modified_text = "[Speak very slowly and clearly] " .. text
    elseif tone_hint == "Fast" then modified_text = "[Speak very fast] " .. text
    end
    return modified_text
end

local function playTTS(text, voice, tone_hint)
    if text == nil or text == "" then 
        service.speak("Please enter some text first.")
        resetToGenerateState()
        return 
    end
    
    btnGenerate.setText("Generating...")
    stopAudio()
    
    local modified_text = applyTone(text, tone_hint)
    local encodedText = URLEncoder.encode(modified_text, "UTF-8")
    local streamUrl = tts_api_url .. "?voice=" .. voice .. "&text=" .. encodedText
    
    mediaPlayer = MediaPlayer()
    mediaPlayer.setDataSource(streamUrl)
    mediaPlayer.prepareAsync()
    
    mediaPlayer.setOnPreparedListener(MediaPlayer.OnPreparedListener{
        onPrepared=function(mp)
            mp.start()
            btnGenerate.setText("Pause")
            btnDownload.setVisibility(View.VISIBLE)
        end
    })
    
    mediaPlayer.setOnErrorListener(MediaPlayer.OnErrorListener{
        onError=function(mp, what, extra)
            service.speak("Error generating audio.")
            resetToGenerateState()
            return true
        end
    })
    
    mediaPlayer.setOnCompletionListener(MediaPlayer.OnCompletionListener{
        onCompletion=function(mp)
            btnGenerate.setText("Play")
            mp.seekTo(0)
        end
    })
end

local function downloadTTS(text, voice, tone_hint)
    service.speak("Download started...")
    
    local modified_text = applyTone(text, tone_hint)
    local encodedText = URLEncoder.encode(modified_text, "UTF-8")
    local downloadUrl = tts_api_url .. "?voice=" .. voice .. "&text=" .. encodedText
    
    local timestamp = os.time()
    local fileName = "TTS_" .. voice .. "_" .. timestamp .. ".mp3"
    local savePath = Environment.getExternalStorageDirectory().toString() .. "/Download/" .. fileName
    
    Http.download(downloadUrl, savePath, function(code, data)
        if code == 200 then
            service.speak("Saved to Download folder successfully.")
        else
            service.speak("Download failed. Code: " .. tostring(code))
        end
    end)
end

-- ==========================================
-- 2. Main UI Layout
-- ==========================================
local layout = {
  LinearLayout;
  orientation="vertical";
  padding="20dp";
  {
    TextView;
    id="titleText";
    text="Digital Text to Audio GENERATE";
    textSize="20sp";
    textColor="#000000";
    paddingBottom="10dp";
  };
  {
    TextView;
    text="Select Voice:";
    textColor="#333333";
  };
  {
    Spinner;
    id="voiceSpinner";
    layout_width="fill";
    layout_marginBottom="5dp";
  };
  {
    TextView;
    text="Select Tone:";
    textColor="#333333";
  };
  {
    Spinner;
    id="toneSpinner";
    layout_width="fill";
    layout_marginBottom="10dp";
  };
  {
    EditText;
    id="textInput";
    hint="Paste or type your text here...";
    layout_width="fill";
    layout_height="120dp";
    gravity="top|left";
    inputType="textMultiLine";
  };
  {
    Button;
    id="btnGenerate";
    text="Generate";
    layout_width="fill";
    layout_marginTop="10dp";
  };
  {
    Button;
    id="btnDownload";
    text="Download MP3";
    layout_width="fill";
    layout_marginTop="5dp";
    visibility=View.GONE; 
  };
  {
    LinearLayout;
    orientation="horizontal";
    layout_width="fill";
    layout_marginTop="15dp";
    {
      Button;
      id="btnAbout";
      text="About";
      layout_weight="1";
    };
    {
      Button;
      id="btnExit";
      text="Exit";
      layout_weight="1";
      textColor="#D32F2F"; 
    };
  };
}

local dlg = AlertDialog.Builder(service)
dlg.setView(loadlayout(layout))
dlg.setCancelable(false) 
local dialog = dlg.create()
dialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)

titleText.getPaint().setFakeBoldText(true)

local voiceAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_dropdown_item, String(voices_list))
voiceSpinner.setAdapter(voiceAdapter)
voiceSpinner.setSelection(loadSavedVoiceIndex())

local toneAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_dropdown_item, String(tones_list))
toneSpinner.setAdapter(toneAdapter)

-- ==========================================
-- 3. Interaction Events
-- ==========================================

voiceSpinner.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{
    onItemSelected=function(parent, view, position, id)
        saveVoiceIndex(position)
        resetToGenerateState()
    end
})

toneSpinner.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{
    onItemSelected=function(parent, view, position, id)
        resetToGenerateState()
    end
})

textInput.addTextChangedListener(TextWatcher{
    onTextChanged=function(s, start, before, count)
        if btnGenerate.getText() ~= "Generate" then
            resetToGenerateState()
        end
    end
})

btnGenerate.onClick = function()
    local btnState = btnGenerate.getText()
    if btnState == "Generate" then
        local selectedVoice = voices_list[voiceSpinner.getSelectedItemPosition() + 1]
        local selectedTone = tones_list[toneSpinner.getSelectedItemPosition() + 1]
        playTTS(textInput.Text, selectedVoice, selectedTone)
    elseif btnState == "Pause" then
        if mediaPlayer and mediaPlayer.isPlaying() then
            mediaPlayer.pause()
            btnGenerate.setText("Play")
        end
    elseif btnState == "Play" then
        if mediaPlayer then
            mediaPlayer.start()
            btnGenerate.setText("Pause")
        end
    end
end

btnDownload.onClick = function()
    local selectedVoice = voices_list[voiceSpinner.getSelectedItemPosition() + 1]
    local selectedTone = tones_list[toneSpinner.getSelectedItemPosition() + 1]
    downloadTTS(textInput.Text, selectedVoice, selectedTone)
end

btnExit.onClick = function()
    stopAudio()
    dialog.dismiss()
end

-- ==========================================
-- 4. About Section
-- ==========================================
btnAbout.onClick = function()
    local aboutLayout = {
        LinearLayout;
        orientation="vertical";
        padding="20dp";
        {
            TextView;
            id="aboutTitle";
            text="CSR Useful Resources";
            textSize="20sp";
            textColor="#000000";
            gravity="center";
            paddingBottom="10dp";
        };
        {
            TextView;
            -- نام اباؤٹ کے اندر بھی تبدیل کر دیا گیا ہے
            text="Digital Text to Audio GENERATE is an advanced Text-to-Speech tool powered by high-quality AI voices. It allows you to seamlessly convert any text into highly realistic, natural-sounding audio.\n\nKey Features:\n• Multiple premium voice options.\n• Emotional and professional tone controls.\n• Real-time audio generation and playback.\n• One-click direct MP3 downloads.\n\nCreated by Noor Hassan and Meer Nasir.\n\n\"A warm welcome to everyone at CSR Useful Resources! 🌟\n> This is your go-to place for the best tools, plugins, and sound schemes for CSR.\"\n\nJoin our community below!";
            textSize="14sp";
            textColor="#333333";
            paddingBottom="20dp";
        };
        {
            Button;
            id="btnJoinTelegram";
            text="Join Telegram";
            layout_width="fill";
            background="#0088cc";
            textColor="#FFFFFF";
        };
        {
            Button;
            id="btnCloseAbout";
            text="Back to Main Menu"; 
            layout_width="fill";
            layout_marginTop="10dp";
        };
    }
    
    local aboutDlg = AlertDialog.Builder(service)
    aboutDlg.setView(loadlayout(aboutLayout))
    local aboutDialog = aboutDlg.create()
    aboutDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    
    aboutTitle.getPaint().setFakeBoldText(true)
    
    btnJoinTelegram.onClick = function()
        aboutDialog.dismiss()
        dialog.dismiss()
        stopAudio()
        local telegram_link = "https://t.me/csrusefulresources" 
        local intent = Intent(Intent.ACTION_VIEW, Uri.parse(telegram_link))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        service.startActivity(intent)
    end
    
    btnCloseAbout.onClick = function()
        aboutDialog.dismiss()
    end
    
    aboutDialog.show()
end

dialog.show()

-- ==========================================
-- 5. Auto Focus on Title
-- ==========================================
-- پلگ ان کھلتے ہی فوکس ٹائٹل پر لے جانے کے لیے
task(200, function()
    titleText.setFocusable(true)
    titleText.setFocusableInTouchMode(true)
    titleText.requestFocus()
end)