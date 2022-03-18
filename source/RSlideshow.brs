function main()
    print("RSlideshow started")
    ' Load
    secret = parseJson(readAsciiFile("pkg:/secret.json"))
    screen = createObject("roSGScreen")
    m.port = createObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.createScene("RSlideshow")

    m.global = screen.getGlobalNode()
    m.global.addFields({
      secret: secret
    })

    screen.show()

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed()
              return ""
            end if
        end if
    end while
end function

function init()
  m.top.setFocus(true)
  ' Components
  m.image = m.top.findNode("image")
  m.video = m.top.findNode("video")
  m.keyboard = m.top.findNode("keyboard")
  m.rslideshow_api = m.top.findNode("rslideshow_api")
  m.registry = m.top.findNode("registry")
  m.timer = m.top.findNode("timer")
  m.title = m.top.findNode("title")
  ' events
  m.rslideshow_api.observeField("result", "on_callback")
  m.registry.observeField("result", "on_callback")
  m.timer.observeField("fire", "on_timer_fire")
  m.image.observeField("loadStatus", "on_image_loaded")
  m.video.observeField("state", "on_video_state_change")
  ' vars
  m.page = []
  m.images = []
  m.index = 0
  ' init
  init_logging()
  m.timer.repeat = true
  m.timer.duration = 5
  m.timer.control = "start"
  read_subreddits_from_registry()
end function

function on_video_state_change(event) as void
    state = event.getData()
    if state = "finished" or state = "error"
      reset_timer()
      on_timer_fire()
    end if
end function

function reset_timer() as void
    m.timer.control = "stop"
    m.timer.control = "start"
end function

function on_image_loaded(event) as void
    reset_timer()
end function

function read_subreddits_from_registry() as void
    m.registry.read = ["RSLIDESHOW", "SUBREDDITS", "on_registry_subreddits"]
end function

function on_timer_fire() as  void
    if m.images.count() = 0
        return
    end if
    if m.index = m.images.count()
        return
    end if
    if m.video.state = "buffering" or m.video.state = "playing" or m.video.state = "paused"
        return
    end if
    if m.image.loadStatus = "loading"
        return
    end if

    m.video.control = "stop"

    image = m.images[m.index]
    is_image = image.url.instr(".mp4") = -1

    m.title.text = "r/" +image.subreddit + " | " + clean(image.title)

    if is_image
        m.image.uri = image.url
        m.video.visible = false
        m.image.visible = true
    else
        content = createObject("roSGNode", "ContentNode")
        content.url = image.url
        m.video.content = content
        m.video.control = "play"

        m.video.visible = true
        m.image.visible = false
    end if

    m.index = m.index + 1

    check_if_should_request_more_images()
end function

function check_if_should_request_more_images() as void
    if m.index = m.images.count()
        read_subreddits_from_registry()
    end if
end function

function add_page_stubs(subreddits) as void
    if m.page.count() > 0
      return
    end if
    subreddits = subreddits.replace(" ", "+")
    for each subreddit in subreddits.split("+")
        m.page.push("")
    end for
end function

function on_registry_subreddits(params) as void
    subreddits = params.getData().result
    add_page_stubs(subreddits)
    m.rslideshow_api.get_images = [subreddits, m.page, "on_api_images"]
end function

function on_api_images(params) as void
    printl(m.DEBUG, "Got images")
    data = params.getData().result
    if data <> invalid
        m.page = data.after
        m.images.append(data.data)
    else
        printl(m.DEBUG, "API error")
        m.index = 0
    end if
end function

' Handle callback
function on_callback(event as object) as void
    callback = event.getData().callback
    if callback = "on_registry_subreddits"
        on_registry_subreddits(event)
    else if callback = "on_registry_subreddits_keyboard"
        on_registry_subreddits_keyboard(event)
    else if callback = "on_registry_subreddits_write"
        on_registry_subreddits_write(event)
    else if callback = "on_api_images"
        on_api_images(event)
    else
        if callback = invalid
            callback = ""
        end if
        printl(m.WARN, "on_callback: Unhandled callback: " + callback)
    end if
end function

function move_left() as void
    m.index = m.index - 2
    if m.index < 0
        m.index = 0
    end if
    reset_timer()
    on_timer_fire()
end function

function move_right() as void
    reset_timer()
    on_timer_fire()
end function

function on_registry_subreddits_keyboard(event) as void
    m.keyboard.text = event.getData().result
    m.keyboard.textEditBox.cursorPosition = m.keyboard.text.len()
end function

function handle_options_key() as void
    if m.keyboard.visible = true
        m.registry.write = ["RSLIDESHOW", "SUBREDDITS", m.keyboard.text, "on_registry_subreddits_write"]
        m.timer.control = "start"
        m.keyboard.visible = false
        m.video.visible = true
        m.image.visible = true
        m.image.setFocus(true)
    else
        m.registry.read = ["RSLIDESHOW", "SUBREDDITS", "on_registry_subreddits_keyboard"]
        m.timer.control = "stop"
        m.keyboard.visible = true
        m.video.control = "stop"
        m.video.visible = false
        m.image.visible = false
        m.keyboard.setFocus(true)
    end if
end function

function on_registry_subreddits_write(event) as void
    m.timer.repeat = true
    m.timer.duration = 5
    m.timer.control = "stop"
    m.timer.control = "start"
    m.images = []
    m.page = []
    m.index = 0
    read_subreddits_from_registry()
end function

function handle_pause() as void
    if m.timer.control = "stop"
        m.timer.control = "start"
    else
        m.timer.control = "stop"
    end if
end function

function handle_back() as boolean
    if m.keyboard.visible
        handle_options_key()
        return true
    else
        return false
    end if
end function

function onKeyEvent(key, press) as Boolean
    if press
        if key = "left"
            move_left()
        else if key = "right"
            move_right()
        else if key = "options" or key = "OK"
            handle_options_key()
        else if key = "play"
            handle_pause()
        else if key = "back"
            return handle_back()
        end if
    end if
end function
