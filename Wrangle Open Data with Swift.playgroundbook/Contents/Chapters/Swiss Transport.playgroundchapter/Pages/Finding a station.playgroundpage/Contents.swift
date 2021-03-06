//#-hidden-code
import Foundation
//#-end-hidden-code
//#-hidden-code
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true
//#-end-hidden-code
//: This URL exposes a service for finding public transport stations
public var stationListURL = URL(string: "https://opentransportdata.swiss/api/action/datastore_search?resource_id=911a4eb7-9d10-440f-904b-b0872b9727c1")!
/*:
 You can filter this list by providing a search term, like a station or place name
 */
var stationName = /*#-editable-code*/"Olten"/*#-end-editable-code*/
//#-editable-code
extension URL {
    mutating func add(stationName: String) {
        let queryItem = URLQueryItem(name: "q", value: stationName)
        if var components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            components.queryItems?.append(queryItem)
            guard let url = components.url else { return }
            self = url
        }
    }
}

stationListURL.add(stationName: stationName)
//#-end-editable-code
/*:
 The response from the service will look something along the lines of this (**Explain CKAN?**)
 
 ```
 {
  "help": "https://opentransportdata.swiss/api/3/action/help_show?name=datastore_search",
  "success": true,
  "result": {
    "resource_id": "911a4eb7-9d10-440f-904b-b0872b9727c1",
    "fields": [
      …
      {
        "type": "numeric",
        "id": "StationID"
      },
      …
    ],
    "q": "Olten, Bahnhof",
    "records": [
      …
      {
        "Station": "Olten, Bahnhof$<1>",
        "StationID": "8572352",
        "_id": 8262,
        "_full_count": "2",
        "rank": 0.0901673
      }
    ],
    "_links": {
      "start": "/api/action/datastore_search?q=Olten%2C+Bahnhof&resource_id=911a4eb7-9d10-440f-904b-b0872b9727c1",
      "next": "/api/action/datastore_search?q=Olten%2C+Bahnhof&offset=100&resource_id=911a4eb7-9d10-440f-904b-b0872b9727c1"
    },
    "total": 2
  }
}
 ```
 
 Here we will focus on getting out the array at `result.records` and transforming this into a typed object.
 
 So we will need to traverse the response object, the result object and the records array and transform its elements.
 
 */
//#-editable-code
struct Response<R: Record> {
    let help: String
    let success: Bool
    let result: Result<R>

    init?(json: AnyObject) {
        guard let help = json.value(forKey: "help") as? String,
            let success = json.value(forKey: "success") as? Bool,
            let resultObject = json.value(forKey: "result") as? AnyObject,
            let result = Result<R>(json: resultObject) else { return nil }
        self.help = help
        self.success = success
        self.result = result
    }
}

struct Result<R: Record> {
    let records: [R]

    init?(json: AnyObject) {
        guard let recordJSON = json.value(forKey: "records") as? [AnyObject] else { return nil }
        records = recordJSON.flatMap(R.init)
    }
}
//#-end-editable-code
/*:
 Notice that the response and result have a generic parameter for the record type they contain.
 For now all we really want a record to require is having an initializer accepting JSON.
 */
protocol Record {
    init?(json: AnyObject)
}
/*:
 All this boilerplate brings us to what we actually want, a station, which is a specific kind of record.
 */
//#-editable-code
struct Station: Record, CustomDebugStringConvertible {
    let station: String
    let stationID: String

    init?(json: AnyObject) {
        guard let station = json.value(forKey: "Station") as? String,
            let stationID = json.value(forKey: "StationID") as? String else { return nil }
        self.station = station
        self.stationID = stationID
    }

    var debugDescription: String {
        get {
            return "\(station) \(stationID)"
        }
    }
}
//#-end-editable-code
/*:
 Let's prepare a task for requesting the list with the URL we prepared earlier, unpack the JSON and try reading the response, assuming that it contains stations.
 */
//#-editable-code
let stationListTask = URLSession.shared.dataTask(with: stationListURL) { (data, response, error) in
    guard error == nil, let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as AnyObject else { error; return }
    if let response = Response<Station>(json: json) {
        response.success
        response.result.records
    }
}
stationListTask.resume()
//#-end-editable-code
/*:
 Next, find out how to find departure or arrival information for a particular station
 */