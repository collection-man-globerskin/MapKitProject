//
//  ViewController.swift
//  MapKitTutorial
//
//  Created by Julian Llorensi on 05/07/2020.
//  Copyright © 2020 Julian Llorensi. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
    typealias AnnotationDictionaryData = [String : Any]
    
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var hybridLabel: UILabel!
    
    private let locationManager: CLLocationManager = CLLocationManager()
    private let regionMeters: Double = 10000
    private var previousLocation: CLLocation?
    private var directions: [MKDirections] = []

    private let annotationData: [AnnotationDictionaryData] = [
        ["title": "Dr James", "latitude": 40.003252, "longitude": -86.0655897],
        ["title": "Avon Town", "latitude": 39.7636057, "longitude": -86.4080829],
        ["title": "Brookside Park", "latitude": 39.7280122, "longitude": -86.0325810],
        ["title": "Hazel", "latitude": 39.3113244, "longitude": -86.1111377],
        ["title": "Washington Park", "latitude": 40.013888, "longitude": -86.5700804]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        checkLocationServices()
        createAnnotation(from: annotationData)
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func centerViewOnUserLocation() {
        guard let location = locationManager.location?.coordinate else { return }
        
        let region = MKCoordinateRegion(center: location, latitudinalMeters: regionMeters, longitudinalMeters: regionMeters)
        mapView.setRegion(region, animated: true)
    }
    
    private func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorization()
        } else {
            let alert = UIAlertController(title: "Services Disabled", message: "You should turn on this service", preferredStyle: .alert)
            present(alert, animated: true)
        }
    }
    
    private func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            startTrackingUserLocation()
        case .denied:
            let alert = UIAlertController(title: "Access Denied", message: "To have this functionality you should enable it in the settings configuration", preferredStyle: .alert)
            present(alert, animated: true)
        case .restricted:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            mapView.showsUserLocation = true
        @unknown default:
            fatalError()
        }
    }
    
    private func startTrackingUserLocation() {
        mapView.showsUserLocation = true
        centerViewOnUserLocation()
        locationManager.startUpdatingLocation()
        previousLocation = getCenterLocation(for: mapView)
    }
    
    private func getDirections() {
        guard let coordinate = locationManager.location?.coordinate else {
            print("We don't have the user location")
            return
        }
        // let coordinate = CLLocationCoordinate2D(latitude: -38.009905, longitude: -57.548548)
        let request = createDirectionsRequest(from: coordinate)
        let directions = MKDirections(request: request)
        resetMapView(with: directions)
        
        directions.calculate(completionHandler: { [unowned self] (response, error) in
            guard let response = response else { return }
            
            for route in response.routes {
                print("Steps: \(route.steps)")
                self.mapView.addOverlay(route.polyline)
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
            }
        })
    }
    
    private func createDirectionsRequest(from coordinate: CLLocationCoordinate2D) -> MKDirections.Request {
        let destinationCoordinate = getCenterLocation(for: mapView).coordinate
        let startingLocation = MKPlacemark(coordinate: coordinate)
        let destination = MKPlacemark(coordinate: destinationCoordinate)
        let request = MKDirections.Request()
        
        request.source = MKMapItem(placemark: startingLocation)
        request.destination = MKMapItem(placemark: destination)
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        return request
    }
    
    private func resetMapView(with newDirections: MKDirections) {
        mapView.removeOverlays(mapView.overlays)
        directions.append(newDirections)
        let _ = directions.map {
            $0.cancel()
            directions.removeAll(where: { $0 == $0 })
        }
    }
    
    private func createAnnotation(from data: [AnnotationDictionaryData]) {
        for location in data {
            let annotation = MKPointAnnotation()
            
            guard let latitude = location["latitude"] as? CLLocationDegrees,
                let longitude = location["longitude"] as? CLLocationDegrees else {
                    return
            }
            
            annotation.title = location["title"] as? String
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            mapView.addAnnotation(annotation)
        }
    }
    
    private func getCenterLocation(for mapView: MKMapView) -> CLLocation {
        return CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
    }
    
    @IBAction func getButtonTapped(_ sender: UIButton) {
        getDirections()
    }
    
    @IBAction func changeMapType(_ sender: UISwitch) {
        mapView.mapType = sender.isOn ? .hybrid : .standard
        hybridLabel.textColor = sender.isOn ? .white : .black
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let center = getCenterLocation(for: mapView)
        let geoCoder = CLGeocoder()
        
        guard let previousLocation = previousLocation, center.distance(from: previousLocation) > 50 else {
            return
        }
        
        self.previousLocation = center
        
        geoCoder.reverseGeocodeLocation(center, completionHandler: { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            if let error = error {
                print(error)
                return
            }
            
            guard let placemark = placemarks?.first else {
                return
            }
            
            let streetNumber = placemark.subThoroughfare ?? ""
            let streetName = placemark.thoroughfare ?? ""
            
            DispatchQueue.main.async {
                self.addressLabel.text = "\(streetNumber) \(streetName)"
            }
        })
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let overlay = overlay as? MKPolyline else { return MKOverlayRenderer() }
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .blue
        
        return renderer
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorization()
    }
}



