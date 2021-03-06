//
//  ViewController.swift
//  CS125LectureFeedback
//
//  Created by Bliss Chapman on 10/18/15.
//  Copyright © 2015 Bliss Chapman. All rights reserved.
//

import UIKit

private var buttonEnabledContext = 0

class NetIDViewController: UIViewController {
    
    @IBOutlet weak var partnerIDTextField: NetIDTextField!
    @IBOutlet weak var netIDTextField: NetIDTextField!
    @IBOutlet weak var navBar: UINavigationItem!
    @IBOutlet weak var nextButton: UIUCButton!
    @IBOutlet weak var qrScanButton: UIButton!
    
    var displayKeyboardAutomatically = true
    
    //a constant structure that contains the name of all segues from the NetIDViewController - this is purely for readability
    private struct Segues {
        static let toOptionalFeedback = "toOptionalFeedback"
        static let toScanner = "displayScanner"
    }
    
    private var feedbackObject: Feedback!
    
    //MARK: View Controller Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
    }
    
    //MARK: UI
    private func configureUI() {
        //disable the nextButton by default and add an observer on the enabled property that will appropriately update its background color every time the enabled status changes to indicate interactivity
        nextButton.enabled = false
        nextButton.addObserver(self, forKeyPath: "enabled", options: [NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Initial], context: &buttonEnabledContext)
        
        qrScanButton.tintColor = UIUCColor.BLUE
        
        //set the NetIDViewController class (self) as the text field's delegates
        partnerIDTextField.delegate = self
        netIDTextField.delegate = self
        
        //display the appropriate keyboard based on if there was a previously cached net id
        if let cachedID = Feedback.UsersID {
            netIDTextField.text = cachedID
            if displayKeyboardAutomatically { partnerIDTextField.becomeFirstResponder() }
        } else {
            if displayKeyboardAutomatically { netIDTextField.becomeFirstResponder() }
        }
    }
    
    @IBAction private func nextButtonTapped(sender: UIUCButton) {
        guard let netID = netIDTextField.text where netID.isValidNetID() else {
            return
        }
        guard let partnerID = partnerIDTextField.text where partnerID.isValidNetID() else {
            return
        }
        
        //save the users net id to use in pre-populating the text field
        // so that the next time the user opens the app they don't need to type as much
        Feedback.UsersID = netID
        
        //instantiate a new instance of Feedback with the netID and partnerID we just retrieved from the user
        feedbackObject = Feedback(netID: netID, partnerID: partnerID)
        performSegueWithIdentifier(Segues.toOptionalFeedback, sender: nil)
    }
    
    @IBAction private func scanButtonTapped(sender: UIButton) {
        //dismiss text fields keyboards
        netIDTextField.resignFirstResponder()
        partnerIDTextField.resignFirstResponder()
        
        //check if the device has a camera
        guard UIImagePickerController.isSourceTypeAvailable(.Camera) else {
            let alert = SCLAlertView()
            alert.showError("Unavailable", subTitle: "Your device does not have a camera.", closeButtonTitle: "Close", duration: .infinity, colorStyle: UIUCColor.BLUE.toHex(), colorTextButton: UIColor.whiteColor().toHex())
            return
        }
        
        //check if the user has granted us permission to use the camera
        guard QRCodeHelper.cameraAccessIsAllowed() else {
            let alert = SCLAlertView()
            alert.addButton("Open Settings", action: { () -> Void in
                UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
            })
            alert.showError("Unavailable", subTitle: "To access this feature, please allow us to access your camera.", closeButtonTitle: "Close", duration: .infinity, colorStyle: UIUCColor.BLUE.toHex(), colorTextButton: UIColor.whiteColor().toHex())
            return
        }
        
        
        performSegueWithIdentifier(Segues.toScanner, sender: nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let identifier = segue.identifier {
            if identifier == Segues.toOptionalFeedback {
                if let vc = segue.destinationViewController as? SubmitViewController {
                    //set the feedbackObject property of the SubmitViewController class we are segueing to to the feedbackObject that contains the user's net ids
                    vc.feedbackObject = feedbackObject
                }
            }
        }
    }
    
    @IBAction func unwindToNetIDViewController(segue:UIStoryboardSegue) {
        if let qrScanner = segue.sourceViewController as? QRScannerViewController {
            if let partnerID = qrScanner.validPartnerID {
                partnerIDTextField.text = partnerID
            }
        } else if let feedbackHistory = segue.sourceViewController as? FeedbackHistoryViewController {
            if let partnerID = feedbackHistory.selectedPartnerID {
                partnerIDTextField.text = partnerID
            }
        }
        nextButton.enabled = nextButtonEnabled()
    }
    
    private func nextButtonEnabled() -> Bool {
        if let partnerID = partnerIDTextField.text {
            if let netID = netIDTextField.text {
                return netID.isValidNetID() && partnerID.isValidNetID()
            }
        }
        return false
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    //Any time the "Next" button's enabled status changes, update the button's background color accordingly
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        if context == &buttonEnabledContext {
            if let enabled = change?[NSKeyValueChangeNewKey] as? Bool {
                if enabled == true {
                    nextButton.backgroundColor = UIUCColor.BLUE
                } else {
                    nextButton.backgroundColor = UIColor.lightGrayColor()
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    //remove the key value observer when the class is deinitialized because this is UIUC and not Michigan 😉
    deinit {
        nextButton.removeObserver(self, forKeyPath: "enabled", context: &buttonEnabledContext)
    }
}

extension NetIDViewController: UITextFieldDelegate {
    
    //when the user hits next, dismiss the keyboard from one text field and bring the keyboard up on the next text field if appropriate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == netIDTextField {
            netIDTextField.resignFirstResponder()
            partnerIDTextField.becomeFirstResponder()
        } else if textField == partnerIDTextField {
            partnerIDTextField.resignFirstResponder()
        }
        
        return true
    }
    
    //only enable the "Next" button/allow a submission attempt if certain conditions are met
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        
        if let netID = netIDTextField.text {
            if let partnerID = partnerIDTextField.text {
                if let newText = textField.text?.stringByAppendingString(string) {
                    
                    switch textField {
                    case netIDTextField: nextButton.enabled = partnerID.isValidNetID() && newText.isValidNetID()
                    case partnerIDTextField: nextButton.enabled = netID.isValidNetID() && newText.isValidNetID()
                    default: break
                    }
                    return true
                    
                }
            }
        }
        
        nextButton.enabled = false
        return true
    }
    
    //if the text field is cleared, the button should be disabled
    func textFieldShouldClear(textField: UITextField) -> Bool {
        nextButton.enabled = false
        return true
    }
}