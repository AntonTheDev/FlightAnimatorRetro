//
//  FAAnimationGroup.swift
//  FlightAnimator
//
//  Created by Anton Doudarev on 2/24/16.
//  Copyright © 2016 Anton Doudarev. All rights reserved.
//

import Foundation
import UIKit

/**
 Equatable FAAnimationGroup Implementation
 */

func ==(lhs:FAAnimationGroup, rhs:FAAnimationGroup) -> Bool {
    return lhs.animatingLayer == rhs.animatingLayer &&
        lhs.animationKey == rhs.animationKey
}

/**
 Timing Priority to apply during synchronisation of hte animations
 within the calling animationGroup.
 
 The more property animations within a group, the more likely some
 animations will need more control over the synchronization of
 the timing over others.
 
 There are 4 timing priorities to choose from:
 
 .MaxTime, .MinTime, .Median, and .Average
 
 By default .MaxTime is applied, so lets assume we have 4 animations:
 
 1. bounds
 2. position
 3. alpha
 4. transform
 
 FABasicAnimation(s) are not defined as primary by default,
 synchronization will figure out the relative progress for each
 property animation within the group in flight, then adjust the
 timing based on the remaining progress to the final destination
 of the new animation being applied.
 
 Then based on .MaxTime, it will pick the longest duration form
 all the synchronized property animations, and resynchronize the
 others with a new duration, and apply it to the group itself.
 
 If the isPrimary flag is set on the bounds and position
 animations, it will only include those two animation in
 figuring out the the duration.
 
 Use .MinTime, to select the longest duration in the group
 Use .MinTime, to select the shortest duration in the group
 Use .Median,  to select the median duration in the group
 Use .Average, to select the average duration in the group

 - MaxTime: find the longest duration, and adjust all animations to match
 - MinTime: find the shortest duration and adjust all animations to match
 - Median:  find the median duration, and adjust all animations to match
 - Average: find the average duration, and adjust all animations to match
 */

public enum FAPrimaryTimingPriority : Int {
    case MaxTime
    case MinTime
    case Median
    case Average
}

//MARK: - FAAnimationGroup

public class FAAnimationGroup : CAAnimationGroup {
       
    public var animationKey : String?
    public weak var animatingLayer : CALayer? { didSet { synchronizeSubAnimationLayers() }}
    public var startTime : CFTimeInterval?  { didSet { synchronizeSubAnimationStartTime() }}
    
    public var timingPriority : FAPrimaryTimingPriority = .MaxTime
    internal weak var primaryAnimation : FABasicAnimation?
    
    public var autoreverse: Bool = false
    public var autoreverseCount: Int = 1
    public var autoreverseDelay: NSTimeInterval = 0.0
    public var autoreverseEasing: Bool = false
    
    internal var _autoreverseActiveCount: Int = 1
    internal var _autoreverseConfigured: Bool = false

    public var isTimeRelative = true
    public var progessValue : CGFloat = 0.0
    public var triggerOnRemoval : Bool = false
    
    override public init() {
        super.init()
        animations = [CAAnimation]()
        fillMode = kCAFillModeForwards
        removedOnCompletion = true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func copyWithZone(zone: NSZone) -> AnyObject {
        
        let animationGroup = super.copyWithZone(zone) as! FAAnimationGroup
       
        animationGroup.animatingLayer          = animatingLayer
        animationGroup.animationKey            = animationKey
        
        animationGroup.animations              = animations
        animationGroup.duration                = duration
    
        animationGroup.primaryAnimation        = primaryAnimation
        animationGroup.startTime               = startTime
        animationGroup.timingPriority          = timingPriority
        
        animationGroup.autoreverse             = autoreverse
        animationGroup.autoreverseCount        = autoreverseCount
        animationGroup.autoreverseDelay        = autoreverseDelay
        animationGroup.autoreverseEasing      = autoreverseEasing
        
        animationGroup._autoreverseActiveCount  = _autoreverseActiveCount
        animationGroup._autoreverseConfigured   = _autoreverseConfigured
        
        return animationGroup
    }
    
    final public func synchronizeAnimationGroup(withLayer layer: CALayer, forKey key: String?) {
        
        animationKey = key
        animatingLayer = layer
      
        if let keys = animatingLayer?.animationKeys() {
            for key in Array(Set(keys)) {
                if let oldAnimation = animatingLayer?.animationForKey(key) as? FAAnimationGroup {
                    _autoreverseActiveCount = oldAnimation._autoreverseActiveCount
                    synchronizeAnimations(oldAnimation)
                }
            }
        } else {
            synchronizeAnimations(nil)
        }
    }
    
    
    
    /**
     Not Ready for Prime Time, being declared as private
     
     Adjusts animation based on the progress form 0 - 1
     
     - parameter progress: scrub "to progress" value
     
     private func scrubToProgress(progress : CGFloat) {
     animatingLayer?.speed = 0.0
     animatingLayer?.timeOffset = CFTimeInterval(duration * Double(progress))
     }
     */
}

//MARK: - Auto Reverse Logic

extension FAAnimationGroup {
 
    func configureAutoreverseIfNeeded() {
        if autoreverse {
            
            if _autoreverseConfigured == false {
                configuredAutoreverseGroup()
            }
            
            if autoreverseCount == 0 {
                return
            }
            
            if _autoreverseActiveCount >= (autoreverseCount * 2) {
                clearAutoreverseGroup()
                return
            }
            
            _autoreverseActiveCount = _autoreverseActiveCount + 1
        }
    }
    
    func configuredAutoreverseGroup() {

        let animationGroup = FAAnimationGroup()
        
        animationGroup.animationKey             = animationKey! + "REVERSE"
        animationGroup.animatingLayer           = animatingLayer
        animationGroup.animations               = reverseAnimationArray()
        animationGroup.duration                 = duration
        
        animationGroup.timingPriority          = timingPriority
        animationGroup.autoreverse             = autoreverse
        animationGroup.autoreverseCount        = autoreverseCount
        animationGroup._autoreverseActiveCount  = _autoreverseActiveCount
        animationGroup.autoreverseEasing      = autoreverseEasing
   /*
        if let view =  animatingLayer?.owningView() {
            let progressDelay = max(0.0 , _autoreverseDelay/duration)
            //configureAnimationTrigger(animationGroup, onView: view, atTimeProgress : 1.0 + CGFloat(progressDelay))
        }
    */
        removedOnCompletion = false
    }
    
    func clearAutoreverseGroup() {
        //_segmentArray = [FAAnimationTrigger]()
        // removedOnCompletion = true
        //stopTriggerTimer()
    }
    
    func reverseAnimationArray() ->[FABasicAnimation] {
        
        var reverseAnimationArray = [FABasicAnimation]()
        
        if let animations = animations {
            for animation in animations {
                if let customAnimation = animation as? FABasicAnimation {
                    
                    let newAnimation = FABasicAnimation(keyPath: customAnimation.keyPath)
                    newAnimation.easingFunction = autoreverseEasing ? customAnimation.easingFunction.autoreverseEasing() : customAnimation.easingFunction
                    
                    newAnimation.isPrimary = customAnimation.isPrimary
                    newAnimation.values = customAnimation.values!.reverse()
                    newAnimation.toValue = customAnimation.fromValue
                    newAnimation.fromValue = customAnimation.toValue
                    
                    reverseAnimationArray.append(newAnimation)
                }
            }
        }
        
        return reverseAnimationArray
    }
}


//MARK: - Synchronization Logic

internal extension FAAnimationGroup {
    
    /**
     Synchronizes the calling animation group with the passed animation group
     
     - parameter oldAnimationGroup: old animation in flight
     */
    func synchronizeAnimations(oldAnimationGroup : FAAnimationGroup?) {
        
        var durationArray =  [Double]()
        
        var oldAnimations = animationDictionaryForGroup(oldAnimationGroup)
        var newAnimations = animationDictionaryForGroup(self)
        
        // Find all Primary Animations
        let filteredPrimaryAnimations = newAnimations.filter({ $0.1.isPrimary == true })
        let filteredNonPrimaryAnimations = newAnimations.filter({ $0.1.isPrimary == false })
        
        var primaryAnimations = [String : FABasicAnimation]()
        var nonPrimaryAnimations = [String : FABasicAnimation]()
        
        for result in filteredPrimaryAnimations {
            primaryAnimations[result.0] = result.1
        }
        
        for result in filteredNonPrimaryAnimations {
            nonPrimaryAnimations[result.0] = result.1
        }
        
        //If no animation is primary, all animations become primary
        if primaryAnimations.count == 0 {
            primaryAnimations = newAnimations
            nonPrimaryAnimations = [String : FABasicAnimation]()
        }
        
        for key in primaryAnimations.keys {
            
            if  let newPrimaryAnimation = primaryAnimations[key] {
                let oldAnimation : FABasicAnimation? = oldAnimations[key]
                
                newPrimaryAnimation.synchronize(relativeTo: oldAnimation)
                
                if newPrimaryAnimation.duration > 0.0 {
                    durationArray.append(newPrimaryAnimation.duration)
                }
                newAnimations[key] = newPrimaryAnimation
            }
        }
        
        animations = newAnimations.map {$1}
        updateGroupDurationBasedOnTimePriority(durationArray)
        
        // configureAutoreverseIfNeeded()
    }
    
    /**
     Updates and syncronizes animations based on timing priority 
     if the primary animations
     
     - parameter durationArray: durations considered based on primary state of the animations
     */
    func updateGroupDurationBasedOnTimePriority(durationArray: Array<CFTimeInterval>) {
        
        switch timingPriority {
        case .MaxTime:
            duration = durationArray.maxElement()!
        case .MinTime:
            duration = durationArray.minElement()!
        case .Median:
            duration = durationArray.sort(<)[durationArray.count / 2]
        case .Average:
            duration = durationArray.reduce(0, combine: +) / Double(durationArray.count)
        }

        var filteredPrimaryAnimations = animations!.filter({
            $0.duration == duration || timingPriority == .Average || timingPriority == .Median && $0.duration > 0.0
        })
        
        if let primaryDrivingAnimation = filteredPrimaryAnimations.first as? FABasicAnimation {
            primaryAnimation = primaryDrivingAnimation
        }
        
        var filteredNonAnimation = animations!.filter({ $0 != primaryAnimation })
        
        for animation in animations! {
            
            animation.duration = duration
            
            if let customAnimation = animation as? FABasicAnimation {
                customAnimation.synchronize()
            }
        }
    }
    
    func synchronizeSubAnimationLayers() {
        if let currentAnimations = animations {
            for animation in currentAnimations {
                if let customAnimation = animation as? FABasicAnimation {
                    customAnimation.animatingLayer = animatingLayer
                }
            }
        }
    }
    
    func synchronizeSubAnimationStartTime() {
        if let currentAnimations = animations {
            for animation in currentAnimations {
                if let customAnimation = animation as? FABasicAnimation {
                    customAnimation.startTime = startTime
                }
            }
        }
        
        if let currentAnimations = animations {
            for animation in currentAnimations {
                if let customAnimation = animation as? FABasicAnimation {
                    customAnimation.animatingLayer = animatingLayer
                }
            }
        }
    }
    
    func animationDictionaryForGroup(animationGroup : FAAnimationGroup?) -> [String : FABasicAnimation] {
        var animationDictionary = [String: FABasicAnimation]()
        
        if let group = animationGroup {
            if let currentAnimations = group.animations {
                for animation in currentAnimations {
                    if let customAnimation = animation as? FABasicAnimation {
                        animationDictionary[customAnimation.keyPath!] = customAnimation
                    }
                }
            }
        }
        
        return animationDictionary
    }
}


//MARK: - Animation Progress Values

internal extension FAAnimationGroup {
    
    func valueProgress() -> CGFloat {
    
        if let animation = animatingLayer?.animationForKey(animationKey!) as? FAAnimationGroup{
            return animation.primaryAnimation!.valueProgress()
        }
        
        guard let primaryAnimation = primaryAnimation else {
            print("Primary Animation Nil")
            return 0.0
        }
        
        return primaryAnimation.valueProgress()
    }
    
    func timeProgress() -> CGFloat {
        
        
        if let animation = animatingLayer?.animationForKey(animationKey!) as? FAAnimationGroup{
            return animation.primaryAnimation!.timeProgress()
        }
        
        guard let primaryAnimation = primaryAnimation else {
            print("Primary Animation Nil")
            return 0.0
        }
        
        return primaryAnimation.timeProgress()
    }
}


/**
 Attaches the specified animation, on the specified view, and relative
 the progress value type defined in the method call
 
 Ommit both timeProgress and valueProgress, to trigger the animation specified
 at the start of the calling animation group
 
 Ommit timeProgress, to trigger the animation specified
 at the relative time progress of the calling animation group
 
 Ommit valueProgress, to trigger the animation specified
 at the relative value progress of the calling animation group
 
 If both valueProgres, and timeProgress values are defined,
 it will trigger the animation specified at the relative time
 progress of the calling animation group
 
 - parameter animation:     the animation or animation group to attach
 - parameter view:          the view to attach it to
 - parameter timeProgress:  the relative time progress to trigger animation on the view
 - parameter valueProgress: the relative value progress to trigger animation on the view
 */
/*
 
 public func triggerAnimation(animation : AnyObject,
 onView view : UIView,
 atTimeProgress timeProgress: CGFloat? = nil,
 atValueProgress valueProgress: CGFloat? = nil) {
 
 configureAnimationTrigger(animation,
 onView : view,
 atTimeProgress : timeProgress,
 atValueProgress : valueProgress)
 }
 */
