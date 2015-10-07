 /*
*     Copyright 2015 IBM Corp.
*     Licensed under the Apache License, Version 2.0 (the "License");
*     you may not use this file except in compliance with the License.
*     You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*     Unless required by applicable law or agreed to in writing, software
*     distributed under the License is distributed on an "AS IS" BASIS,
*     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*     See the License for the specific language governing permissions and
*     limitations under the License.
*/


/**
    The HTTP method to be used in the `Request` initializer.
*/
public enum HttpMethod: String {
    case GET, POST, PUT, DELETE, TRACE, HEAD, OPTIONS, CONNECT, PATCH
}

// CODE REVIEW: Create custom ErrorType called "MFPError" - case for NSURL and case for appendQueryParameters
// CODE REVIEW: Figure out how to create a message associated with the error
private enum MFPError: String, ErrorType {
    case test = "aadsf"
    
    
}
 
// CODE REVIEW: REMOVE JSON EVERYWHERE

/**
    Build and send HTTP network requests.

    When building a Request object, all properties must be provided in the initializer, 
        except for the `requestBody`, which can be supplied as NSData, JSON, or text via one of the following methods:

        setRequestBodyWithJSON(requestJSON: AnyObject)
        setRequestBodyWithString(requestString: String)
        setRequestBodyWithData(requestData: NSData)

    The response received from the server is parsed into a `MFPResponse` object which is returned
        in the `sendWithCompletionHandler` callback.
*/
public class Request: NSObject, NSURLSessionTaskDelegate {

    
    // MARK: Constants
    
    static let CONTENT_TYPE = "Content-Type"
    static let JSON_CONTENT_TYPE = "application/json"
    static let TEXT_PLAIN_TYPE = "text/plain"
    
    // CODE REVIEW: Replace setRequestBodyWith... and send methods
    func sendWithCompletionHandler() {}
    func sendString(requestBody: String) {}
    func sendData(requestBody: NSData) {}
    
    
    
    // MARK: Properties (public)
    
    /// URL that the request is being sent to
    public private(set) var resourceUrl: NSURL
    
    /// HTTP method (GET, POST, etc.)
    public let httpMethod: HttpMethod
    
    /// Request timeout measured in seconds
    public var timeout: Double
    
    /// All request headers. The "Content-Type" header is set by the `setRequestBody` methods.
    public private(set) var headers: [String: String]
    
    /// Query parameters to append to the `resourceURL`
    public var queryParameters: [String: String]?
    
    /// The request body can be supplied as NSData, JSON, or String, but is always converted to NSData
    ///     before sending the request.
    public private(set) var requestBody: NSData?
    
    
    
    // MARK: Properties (internal/private)
    
    var networkSession: NSURLSession
    var networkRequest: NSMutableURLRequest
    var allowRedirects: Bool = true
    private var startTime: NSTimeInterval = 0.0
    
    
    
    // MARK: Initializers
    
    /**
        Constructs a new request with the specified URL, using the specified HTTP method.
        Additionally this constructor sets a custom timeout.

        - parameter url:             The resource URL
        - parameter method:          The HTTP method to use.
        - parameter timeout:         Optional timeout in seconds for this request.
        - parameter headers:         Optional headers to add to the request.
        - parameter queryParameters: Optional query parameters to add to the request.
    */
    // CODE REVIEW: url parameter should be String, and converted to an NSURL
    // CODE REVIEW: Handle url String -> NSURL conversion failure in send() methods (return error in callback)
    public init(url: NSURL,
               method: HttpMethod = HttpMethod.GET,
               timeout: Double = BMSClient.sharedInstance.defaultRequestTimeout,
               headers: [String: String] = [:],
               queryParameters: [String: String] = [:]) {
        
        self.resourceUrl = url
        self.httpMethod = method
        self.headers = headers
        self.timeout = timeout
        self.queryParameters = queryParameters
        
        // Set timeout and initialize network session and request
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = timeout
        networkSession = NSURLSession(configuration: configuration)
        networkRequest = NSMutableURLRequest()
                
        super.init()
        
        self.resourceUrl = Request.appendQueryParameters(queryParameters, toURL: url)
    }
    
    
    
    // MARK: Methods (public)
    
    /**
        Sets the request body for the network request by first converting the JSON to NSData.
        Sets the Content-Type header to "application/json" if it is not already set.
    
        **Warning:** This method may throw an NSException. As of Swift 2.0, NSExceptions cannot be caught,
            so this would cause the app to crash. Ensure that the `requestJSON` parameter is valid JSON.

        - parameter requestJSON: The request body in JSON format
    */
    public func setRequestBodyWithJSON(requestJSON: AnyObject) {
        
        do {
            requestBody = try NSJSONSerialization.dataWithJSONObject(requestJSON, options: NSJSONWritingOptions.PrettyPrinted)
        }
        catch {
            // Swift cannot catch NSExceptions anyway, so no use in making the user implement a do/try/catch
        }
        
        if let _ = headers[Request.CONTENT_TYPE] {}
        else {
            headers[Request.CONTENT_TYPE] = Request.JSON_CONTENT_TYPE
        }
    }
    
    
    /**
        Sets the request body for the network request by first converting the String to NSData.
        Sets the Content-Type header to "text/plain" if it is not already set.
    
        - parameter requestString: Request body as a string. Must conform to UTF-8 encoding.
    */
    public func setRequestBodyWithString(requestString: String) {
        
        requestBody = requestString.dataUsingEncoding(NSUTF8StringEncoding)
        
        if let _ = headers[Request.CONTENT_TYPE] {}
        else {
            headers[Request.CONTENT_TYPE] = Request.TEXT_PLAIN_TYPE
        }
    }
    
    
    /**
        Sets the request body for the network request.
    
        - parameter requestData: Request body as NSData
    */
    public func setRequestBodyWithData(requestData: NSData) {
        
        requestBody = requestData
    }
    
    
    /**
        Send this resource request asynchronously. 
        The response received from the server is parsed into a `Response` object which is passed back
            via the `callback` parameter.

        - parameter completionHandler: The closure that will be called when this request finishes.
    */
    public func sendWithCompletionHandler(callback: ((MFPResponse, ErrorType?) -> Void)?) {
        
        
        
        // Build the BMSResponse object, and pass it to the user
        let buildAndSendResponse = {
            (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            
            // TODO: Make use of the round trip time with Analytics
            let roundTripTime = NSDate.timeIntervalSinceReferenceDate() - self.startTime
            
            let networkResponse = MFPResponse(responseData: data, httpResponse: response as? NSHTTPURLResponse, isRedirect: self.allowRedirects)
            
            callback?(networkResponse as MFPResponse, MFPError.test)
        }
        
        // Build request
        networkRequest.URL = resourceUrl
        networkRequest.HTTPMethod = httpMethod.rawValue
        networkRequest.allHTTPHeaderFields = headers
        networkRequest.HTTPBody = requestBody
        
        startTime = NSDate.timeIntervalSinceReferenceDate()
        
        // Send request
        networkSession.dataTaskWithRequest(networkRequest as NSURLRequest, completionHandler: buildAndSendResponse).resume()
    }
    
    
    
    // MARK: NSURLSessionTaskDelegate
    
    // Handle HTTP redirection
    public func URLSession(session: NSURLSession,
        task: NSURLSessionTask,
        willPerformHTTPRedirection response: NSHTTPURLResponse,
        newRequest request: NSURLRequest,
        completionHandler: ((NSURLRequest?) -> Void))
    {
        var redirectRequest: NSURLRequest?
        
        if allowRedirects {
            redirectRequest = request
        }
        
        completionHandler(redirectRequest)
    }

    
    
    // MARK: Methods (internal/private)
    
    /**
        Returns the supplied URL with query parameters appended to it; the original URL is not modified.
        Characters in the query parameters that are not URL safe are automatically converted to percent-encoding.
    
        - parameter parameters:  The query parameters to be appended to the end of the url string
        - parameter originalURL: The url that the `parameters` will be appeneded to
    
        - returns: The original URL with the query parameters appended to it
    */
    static func appendQueryParameters(parameters: [String: String], toURL originalUrl: NSURL) -> NSURL {
        
        if parameters.isEmpty {
            return originalUrl
        }
        
        var parametersInURLFormat = [NSURLQueryItem]()
        for (key, value) in parameters {
            parametersInURLFormat += [NSURLQueryItem(name: key, value: value)]
        }
        // CODE REVIEW: Append parameters to existing parameters
        let newUrlComponents = NSURLComponents(URL: originalUrl, resolvingAgainstBaseURL: false)
        newUrlComponents?.queryItems = parametersInURLFormat
        
        if let newUrl = newUrlComponents?.URL {
            return newUrl
        }
        else {
            // CODE REVIEW: Like with resourceUrl, check if this works in the send() methods and pass a custom error back to completion handler
            
            // TODO: Log a warning or error here
            return originalUrl
        }
    }
    
}






