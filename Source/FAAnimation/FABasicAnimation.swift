//
//  FAAnimation.swift
//  FlightAnimator
//
//  Created by Anton Doudarev on 2/24/16.
//  Copyright © 2016 Anton Doudarev. All rights reserved.
//

import Foundation
import UIKit

//MARK: - FASynchronizedAnimation

public class FABasicAnimation : FASynchronizedAnimation {

    override public init() {
        super.init()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Final animation value to interpolate to
    public var toValue: AnyObject? {
        get { return _toValue }
        set { _toValue = newValue }
    }
    
    // Final animation value to interpolate to
    public var fromValue: AnyObject? {
        get { return _fromValue }
        set { _fromValue = newValue }
    }

    // The easing funtion applied to the duration of the animation
    public var easingFunction : FAEasing  {
        get { return _easingFunction }
        set { _easingFunction = newValue }
    }
    
    // Flag used to track the animation as a primary influencer 
    // for the overall timing within an animation group.
    public var isPrimary : Bool {
        get { return (easingFunction.isSpring() || _isPrimary) }
        set { _isPrimary = newValue }
    }
    
    public func scrubToProgress(progress : CGFloat) {
        weakLayer?.speed = 0.0
        weakLayer?.timeOffset = CFTimeInterval(duration * Double(progress))
    }
}


//MARK: - FASynchronizedAnimation

public class FASynchronizedAnimation : CAKeyframeAnimation {

    // fromValue auto synchronizes with current presentation layer values
    internal var _fromValue: AnyObject?
    internal var _toValue: AnyObject?
    internal var _easingFunction : FAEasing = FAEasing.Linear
    internal var _isPrimary : Bool = false
    
    internal weak var weakLayer : CALayer?
    internal var interpolator : Interpolator?
    internal var startTime : CFTimeInterval?
    
    override public var timingFunction: CAMediaTimingFunction? {
        didSet {
            print("WARMING: FlightAnimator\n Setting timingFunction on an FABasicAnimation has no effect, use the 'easingFunction' property instead\n")
        }
    }
    
    override public init() {
        super.init()
        CALayer.swizzleAddAnimation()
        
        calculationMode = kCAAnimationLinear
        fillMode = kCAFillModeForwards
        removedOnCompletion = true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func copyWithZone(zone: NSZone) -> AnyObject {
        let animation = super.copyWithZone(zone) as! FABasicAnimation
        animation.weakLayer             = weakLayer
        animation.startTime             = startTime
        animation.interpolator          = interpolator
        animation._easingFunction       = _easingFunction
        animation._toValue              = _toValue
        animation._fromValue            = _fromValue
        animation._isPrimary            = _isPrimary
        return animation
    }
    
    final public func configureAnimation(withLayer layer: CALayer?) {
        weakLayer = layer
    }
}

//MARK: - Synchronization Logic

internal extension FASynchronizedAnimation {
    
    func synchronize(runningAnimation animation : FABasicAnimation? = nil) {
        configureValues(animation)
    }
    
    func synchronizeAnimationVelocity(fromValue : Any, runningAnimation : FABasicAnimation?) {
        
        if  let presentationLayer = runningAnimation?.weakLayer?.presentationLayer(),
            let animationStartTime = runningAnimation?.startTime,
            let oldInterpolator = runningAnimation?.interpolator {
            
            let currentTime = presentationLayer.convertTime(CACurrentMediaTime(), toLayer: runningAnimation!.weakLayer)
            let deltaTime = CGFloat(currentTime - animationStartTime) - FAAnimationConfig.AnimationTimeAdjustment
            
            if _easingFunction.isSpring() {
                _easingFunction = oldInterpolator.adjustedEasingVelocity(deltaTime, easingFunction: _easingFunction)
            }
            
        } else {
            switch _easingFunction {
            case .SpringDecay(_):
                _easingFunction =  FAEasing.SpringDecay(velocity: interpolator?.zeroVelocityValue())
                
            case let .SpringCustom(_,frequency,damping):
                _easingFunction = FAEasing.SpringCustom(velocity: interpolator?.zeroVelocityValue() ,
                                                        frequency: frequency,
                                                        ratio: damping)
            default:
                break
            }
        }
    }
    
    func configureValues(runningAnimation : FABasicAnimation? = nil) {
        
        configureFromValueIfNeeded()
        
        synchronizeAnimationVelocity(_fromValue, runningAnimation: runningAnimation)
        
        if let _toValue = _toValue,
            let _fromValue = _fromValue {
            
            interpolator  = Interpolator(toValue: _toValue,
                                         fromValue: _fromValue,
                                         previousValue : runningAnimation?.fromValue)
            
            let config = interpolator?.interpolatedConfiguration(CGFloat(duration), easingFunction: _easingFunction)
            
            duration = config!.duration
            values = config!.values
        }
    }
    
    
    func configureFromValueIfNeeded() {
        
        if _fromValue != nil {
            return
        }
        
        if let presentationLayer = (weakLayer?.presentationLayer() as? CALayer),
            let presentationValue = presentationLayer.anyValueForKeyPath(keyPath!) {
            
            if let currentValue = presentationValue as? CGPoint {
                _fromValue = NSValue(CGPoint : currentValue)
            } else  if let currentValue = presentationValue as? CGSize {
                _fromValue = NSValue(CGSize : currentValue)
            } else  if let currentValue = presentationValue as? CGRect {
                _fromValue = NSValue(CGRect : currentValue)
            } else  if let currentValue = presentationValue as? CGFloat {
                _fromValue = NSNumber(float : Float(currentValue))
            } else  if let currentValue = presentationValue as? CATransform3D {
                _fromValue = NSValue(CATransform3D : currentValue)
            } else if let currentValue = typeCastCGColor(presentationValue) {
                _fromValue = currentValue
            }
        }
    }
}


//MARK: - Animation Progress Values

internal extension FASynchronizedAnimation {
    
    func valueProgress() -> CGFloat {
        if let presentationValue = (weakLayer?.presentationLayer() as? CALayer)?.anyValueForKeyPath(keyPath!) {
            return interpolator!.valueProgress(presentationValue)
        }
        
        return 0.0
    }
    
    func timeProgress() -> CGFloat {
        let currentTime = weakLayer?.presentationLayer()!.convertTime(CACurrentMediaTime(), toLayer: nil)
        let difference = currentTime! - startTime!
        
        return CGFloat(round(100 * (difference / duration))/100)
    }
}
