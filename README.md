# TweakInject

Credits to:
Coolstar, angelXWind

Coolstar: backboardd handler/modifications to TweakInject
AngelXWind: Original sbinject

What the difference is? 

Fishhook is stripped. I originally tried compiling this through theos, before realizing if you use substitute, you need to make modifications to theos Logos to work with substitute (despite coolstar having a PR to logos to do this, I am very lazy)

So, inject TweakInject to any app (with proper entilements) and this will look in the dylibDir set, and dlopen (open a dylib) in the process one by one.


To compile this, if you're using substrate, go somewhere else, if you're using it for another reason, this will work without any code injection platform. You can use inject_criticald with this.
