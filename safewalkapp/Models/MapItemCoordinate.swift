import Foundation
import MapKit

// iOS 26 deprecated MKMapItem.placemark in favour of MKMapItem.location.
// This one property uses the new API where it exists and the old one on earlier iOS,
// so the rest of the app never touches `placemark` directly.
extension MKMapItem {
    var mapCoordinate: CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            let point: CLLocation? = location   // works whether the SDK types it optional or not
            return point?.coordinate ?? kCLLocationCoordinate2DInvalid
        } else {
            return placemark.coordinate
        }
    }
}
