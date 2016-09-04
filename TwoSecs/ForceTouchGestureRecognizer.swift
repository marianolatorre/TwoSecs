//Without this import line, you'll get compiler errors when implementing your touch methods since they aren't part of the UIGestureRecognizer superclass
import UIKit.UIGestureRecognizerSubclass

//Since 3D Touch isn't available before iOS 9, we can use the availability APIs to ensure no one uses this class for earlier versions of the OS.
@available(iOS 9.0, *)
public class ForceTouchGestureRecognizer: UIGestureRecognizer {
    //Since it also doesn't make sense to have our force variable as a settable property, I'm using a private instance variable to make our public force property read-only
    private var _force: CGFloat = 0.0
    
    //Because we don't know what the maximum force will always be for a UITouch, the force property here will be normalized to a value between 0.0 and 1.0.
    public var force: CGFloat { get { return _force } }
    public var maximumForce: CGFloat = 4.0
    
    override public func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesBegan(touches, withEvent: event)
        
        normalizeForceAndFireEvent(.Began, touches: touches)
    }
    
    override public func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesMoved(touches, withEvent: event)
        
        normalizeForceAndFireEvent(.Changed, touches: touches)
    }
    
    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesEnded(touches, withEvent: event)
        
        normalizeForceAndFireEvent(.Ended, touches: touches)
    }
    
    override public func touchesCancelled(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesCancelled(touches, withEvent: event)
        
        normalizeForceAndFireEvent(.Cancelled, touches: touches)
    }
    
    func normalizeForceAndFireEvent(state: UIGestureRecognizerState, touches: Set<UITouch>) {
        //Putting a guard statement here to make sure we don't fire off our target's selector event if a touch doesn't exist to begin with.
        guard let firstTouch = touches.first else {
            return
        }
        
        //Just in case the developer set a maximumForce that is higher than the touch's maximumPossibleForce, I'm setting the maximumForce to the lower of the two values.
        maximumForce = max(firstTouch.maximumPossibleForce, maximumForce)
        
        //Now that I have a proper maximumForce, I'm going to use that and normalize it so the developer can use a value between 0.0 and 1.0.
        _force = firstTouch.force / maximumForce
        
        //Our properties are now ready for inspection by the developer. By setting the UIGestureRecognizer's state property, the system will automatically send the target the selector message that this recognizer was initialized with.
        self.state = state
    }
    
    //This function is called automatically by UIGestureRecognizer when our state is set to .Ended. We want to use this function to reset our internal state.
    public override func reset() {
        super.reset()
        
        _force = 0.0
    }
}