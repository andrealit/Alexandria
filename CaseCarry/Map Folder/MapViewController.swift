//
//  MapViewController.swift
//  CaseCarry
//
//  Created by Andrea Tongsak on 9/7/19.
//  Copyright © 2019 Andrea Tongsak. All rights reserved.
//

import MapKit
import UIKit
import CoreData

// MARK: Setting up delegate

let delegate = UIApplication.shared.delegate as! AppDelegate

class MapViewController: UIViewController, UIGestureRecognizerDelegate, MKMapViewDelegate {
    // MARK: Outlets and Properties
    @IBOutlet weak var mapView: MKMapView!
    
    let stack = delegate.stack
    
    var fetchedResultController: NSFetchedResultsController<NSFetchRequestResult>?
    
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Pin")
    
    let regionRadius: CLLocationDistance = 1000
    
    let locationManager = CLLocationManager()
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.firstSetup()
        self.loadData()
        
        // set initial location in Cleveland's University Circle
        let initialLocation = CLLocation(latitude: 41.5045992, longitude: -81.60971339999998)
        centerMapOnLocation(location: initialLocation)
        
        checkLocationServices()
    }
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            
        } else {
            
        }
    }
    
    func checkAuthorizationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            mapView.showsUserLocation = true
        case .denied:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            mapView.showsUserLocation = true
        case .restricted:
            break
        case .authorizedAlways:
            break
        }
    }
    
    // user adding pin to map view
    @objc func addpin(_ gesture: UILongPressGestureRecognizer)
    {
        if gesture.state == UIGestureRecognizer.State.began
        {
            let loc = gesture.location(in: mapView)
            let coord = mapView.convert(loc, toCoordinateFrom: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coord
            let pin = Pin(lat: coord.latitude, long: coord.longitude, context: (fetchedResultController?.managedObjectContext)!)
            try! stack.saveContext()
            loadData()
        }
    }
    
    // fetching long and lat coordinates
    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        var point: NSManagedObject!
        
        let firstPredicate = NSPredicate(format: "latitude = %@", argumentArray: [(view.annotation?.coordinate.latitude)!])
        let secondPredicate = NSPredicate(format: "longitude = %@", argumentArray: [(view.annotation?.coordinate.longitude)!])
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Pin")
        let combinedPredicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [firstPredicate, secondPredicate])
        
        fetchRequest.predicate = combinedPredicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true)]
        
        fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        fetchCompletion(fetchResultController: fetchedResultController, completion: {
            let objc = fetchedResultController?.fetchedObjects as! [NSManagedObject]
            point = objc[0]
        })
        mapView.deselectAnnotation(view.annotation, animated: false)
        performSegue(withIdentifier: "push", sender: point)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let target = segue.destination as! FlickrViewController
        target.point = sender as! Pin
    }
}

extension MapViewController {
    func firstSetup() {
        mapView.delegate = self
        
        // long-press gesture, creating pin location
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(addpin(_: )))
        gesture.delegate = self
        gesture.minimumPressDuration = 0.5
        gesture.allowableMovement = 1
        mapView.addGestureRecognizer(gesture)
    }
    
    func loadData() {
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: false), NSSortDescriptor(key: "longitude", ascending: false)]
        fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        fetchCompletion(fetchResultController: fetchedResultController, completion: {
            let pin:[Pin] = fetchedResultController?.fetchedObjects as! [Pin]
            DispatchQueue.global(qos: .userInitiated).async
                {
                    var annot = [MKPointAnnotation]()
                    for ann in pin
                    {
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = CLLocationCoordinate2D(latitude: ann.latitude, longitude: ann.longitude)
                        annot.append(annotation)
                    }
                    DispatchQueue.main.async
                        {
                            self.mapView.addAnnotations(annot)
                    }
            }
        })
    }
    
    func fetchCompletion(fetchResultController: NSFetchedResultsController<NSFetchRequestResult>?, completion: ()->()) {
        fetchResultController?.delegate = self as? NSFetchedResultsControllerDelegate
        startSearch()
        completion()
    }
    
    func startSearch() {
        if let fetchResult = fetchedResultController {
            do {
                try fetchResult.performFetch()
            }
            catch let error as NSError {
                print("Error occured while performing search: \n\(error)\n\(String(describing: fetchedResultController))")
            }
        }
    }
}
