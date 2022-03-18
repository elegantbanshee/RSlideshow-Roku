function init() as void
    m.port = createObject("roMessagePort")
    ' Constants

    ' HTTP Api
    initialize_http_agent()
    ' Variables
    m.callback = invalid
    ' Events
    m.top.observeField("get_images", m.port)
    ' Task init
    init_logging()
    m.top.functionName = "run"
    m.top.control = "RUN"
end function

function initialize_http_agent() as void
    if m.http <> invalid
        m.http.asyncCancel()
        m.callback = invalid
    end if
    m.http = createObject("roUrlTransfer")
    m.http.setMessagePort(m.port)
    m.http.setCertificatesFile("common:/certs/ca-bundle.crt")
    m.http.addHeader("X-Roku-Reserved-Dev-Id", "") ' Automatically populated
    m.http.initClientCertificates()
end function

function run() as void
    print("RSlideshow API task started")
    while true
        msg = wait(0, m.port)
        if type(msg) = "roUrlEvent"
            on_http_response(msg)
        else if type(msg) = "roSGNodeEvent"
            if msg.getField() = "get_images"
                get_images(msg)
            end if
        end if
    end while
end function

function on_http_response(event as object) as void
    ' Transfer not complete
    if event.getInt() <> 1 or m.callback = invalid then return
    ' Canceled
    if event.getResponseCode() = -10001 or event.getFailureReason() = "Cancelled"
        return
    ' Fail
    else if event.getResponseCode() <> 200
        url = "Unknown"
        if m.http <> invalid and event.getSourceIdentity() = m.http.getIdentity()
            url = m.http.getUrl()
        else if m.http_twitch <> invalid and event.getSourceIdentity() = m.http_twitch.getIdentity()
            url = m.http_twitch.getUrl()
        end if
        print "HTTP request failed:"
        print tab(2)"URL: " + url
        print tab(2)"Status Code: " + event.getResponseCode().toStr()
        print tab(2)"Reason: " + event.getFailureReason()
        print tab(2)"Body: " + event.getString()
        print tab(2)"Headers: "
        for each header in event.getResponseHeadersArray()
            'print tab(4)header + ": " + event.getResponseHeadersArray()[header]
        end for
    end if
    ' Response
    response = event.getString()
    ' Parse
    json = response
    if m.parse_json
        json = parseJson(json)
    else if event.getResponseCode() <> 200
        json = invalid
    end if
    ' Handle internal callback
      m.top.setField("result", {
        callback: m.callback
        result: json
      })
end function

function get(request_url as string, http_agent as object) as void
    print "Get request to " + request_url
    http_agent.setRequest("GET")
    http_agent.setUrl(request_url)
    http_agent.asyncGetToString()
end function

function post(request_url, data, http_agent) as void
    print "Post request to " + request_url
    http_agent.setRequest("POST")
    http_agent.setUrl(request_url)
    http_agent.asyncPostFromString(data)
end function

function get_images(params as object) as void
    request_url = m.global.secret.api_domain + "/api/data"
    subreddits = params.getData()[0]
    subreddits = subreddits.replace(" ", "+")
    pages = params.getData()[1]
    callback = params.getData()[2]
    data = subreddits + ";" + formatJson(pages)
    url_params = []
    request("POST", request_url, url_params, callback, data)
end function

' Make an async request, automatically handling the callback result and setting it to
' the result field
' A JSON parse is attempted, so the expected data should be JSON
' @param req type of request GET or POST
' @param request_url base URL to call with no parameters
' @param paramas array of string parameters to append in the format "key=value"
' @param callback callback string to embed in result
' @param data optional post body to send
function request(req as string, request_url as string, params as object, callback as string, data = "" as string, http_agent = m.http as object, parse_json = true as boolean) as void
    ' Construct URL from parameter array
    separator = "?"
    if not params.isEmpty()
        for each param in params
            request_url += separator + param
            separator = "&"
        end for
    end if
    ' Make the HTTP request
    m.callback = callback
    m.parse_json = parse_json
    if req = "GET"
        get(request_url, http_agent)
    else if req = "POST"
        post(request_url, data, http_agent)
    end if
end function
