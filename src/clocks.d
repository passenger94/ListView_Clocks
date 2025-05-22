module clocks;

import std.logger;
import std.string : toStringz;
import std.traits; 
import std.typecons : Tuple;

import gobject.types, gobject.object, gobject.dclosure, gobject.value, gobject.global, gobject.param_spec;
import gio.list_store, gio.list_model;
import glib.time_zone, glib.date_time, glib.global;
import gtk.types, gtk.snapshot : SnapshotGtk = Snapshot;
import gdk.types, gdk.paintable, gdk.paintable_mixin, gdk.rgba, gdk.snapshot : SnapshotGdk = Snapshot;
import gsk.rounded_rect;
import graphene.point, graphene.rect;

import gobject.c.types, gobject.c.functions;
import gdk.c.types, gdk.c.functions;


enum Props {
    LOCATION = 1,
    TIME,
    TIMEZONE,
}

/// 
struct ClockClass
{
	GObjectClass parentClass;
}

/// 
class Clock : ObjectWrap, Paintable
{
	static GObjectClass* parentClass = null;

        private static string typeName = "Clock";
    
	protected GdkPaintable* gpaintable;

	this(void* cObj, Flag!"Take" take = No.Take)
	{
		super(cast(GObject*) cObj, take);
		gpaintable = cast(GdkPaintable*) cObj;
	}

    static GType _getGType() { return clockGetType(); }

	private extern(C)
	{
		/*
		 *  here we register our new type and its interfaces with the type system.
		 */
		static GType clockGetType()
		{
			GType clockType = g_type_from_name(Clock.typeName.toStringz());

			if (clockType == GTypeEnum.Invalid)
			{
				GTypeInfo clockInfo = {
					ClockClass.sizeof,                          /* class size */
					null,                                       /* base_init */
					null,                                       /* base_finalize */
					cast(GClassInitFunc) &clockClassInit,       /* class init function */
					null,                                       /* class finalize */
					null,                                       /* class_data */
					GObject.sizeof,                             /* instance size */
					0,                                          /* n_preallocs */
					null
				};

				GInterfaceInfo itfPaintInfo = {
					cast(GInterfaceInitFunc) &clockInit,
					null,
					null
				};

				/* Register the new derived type with the GObject type system */
                clockType = g_type_register_static(GTypeEnum.Object, Clock.typeName.toStringz(), 
                                                   &clockInfo, cast(GTypeFlags)0);

				/* Register our Paintable interface with the type system */
				g_type_add_interface_static(clockType, Paintable._getGType(), &itfPaintInfo);
			}

			return clockType;
		}
        
        static ParamSpec[Props.max+1] properties;

        static void clockClassInit(GTypeClass* klass)
	{
	    GObjectClass* objectClass;

	    parentClass = cast(GObjectClass*) g_type_class_peek_parent(klass);
	    objectClass = cast(GObjectClass*) klass;

            objectClass.getProperty = &clockGetProperty;
            objectClass.setProperty = &clockSetProperty;
            objectClass.finalize = &clockFinalize;

            properties[Props.LOCATION] = 
                paramSpecString("location", null, null, null, ParamFlags.Readwrite | ParamFlags.ConstructOnly);
            properties[Props.TIME] = 
                paramSpecString("time", null, null, null, ParamFlags.Readwrite);
            properties[Props.TIMEZONE] = 
                paramSpecBoxed("timezone", null, null, TimeZone._getGType(), ParamFlags.Readwrite | ParamFlags.ConstructOnly);

            GParamSpec*[properties.length] c_properties;
            foreach (i, ps; properties)
                if (ps)
                    c_properties[i] = cast(GParamSpec*) ps._cPtr();
            
            g_object_class_install_properties(objectClass, Props.max, c_properties.ptr);
	}

	static void clockFinalize(GObject* object)
	{
	    /* must chain up - finalize parent */
	    parentClass.finalize(object);
	}

        static void clockGetProperty(GObject* object, uint propertyId, GValue* value, GParamSpec* pspec)
        {
            auto clock = _getDObject!Clock (object, No.Take);

            import gobject.boxed;
            final switch (propertyId)
            {
                case Props.LOCATION: setVal!string (value, clock.location); break;
                case Props.TIMEZONE: setVal!Boxed (value, clock.timezone); break;
                case Props.TIME: setVal!string (value, clock.time_format); break;
            }
        }

        static void clockSetProperty(GObject* object, uint propertyId, const(GValue)* value, GParamSpec* pspec)
        {
            auto clock = _getDObject!Clock (object, No.Take);

            switch (propertyId)
            {
                case Props.TIME: clock.time_format = getVal!string (value); break;
                default: break;
            }
        }

	static void clockInit(GdkPaintableInterface* iface)
	{
	    iface.snapshot           = &clockSnapshot;
	    iface.getFlags           = &clockGetFlags;
	    iface.getIntrinsicWidth  = &clockGetIntrinsicWidth;
	    iface.getIntrinsicHeight = &clockGetIntrinsicHeight;
	}

        static void clockSnapshot(GdkPaintable* paintable, GdkSnapshot* snapshot, double width, double height)
        {
            auto clock = _getDObject!Clock (paintable, No.Take);
            auto snapshot_ = _getDObject!SnapshotGdk (snapshot, No.Take);

            clock.snapshot(snapshot_, width, height);
        }

        static GdkPaintableFlags clockGetFlags(GdkPaintable* paintable)
	{
            return GdkPaintableFlags.Size;  /* The size is immutable. */
	}

        static int clockGetIntrinsicWidth(GdkPaintable* paintable)
        {
            return 100;
        }

        static int clockGetIntrinsicHeight(GdkPaintable* paintable)
        {
            return 100;
        }
    }

    override void computeConcreteSize(double specifiedWidth, double specifiedHeight, double defaultWidth, double defaultHeight, out double concreteWidth, out double concreteHeight)
    {
        gdk_paintable_compute_concrete_size(cast(GdkPaintable*)_cPtr, specifiedWidth, specifiedHeight, defaultWidth, defaultHeight, cast(double*)&concreteWidth, cast(double*)&concreteHeight);
    }
    
    override gdk.paintable.Paintable getCurrentImage()
    {
        GdkPaintable* _cretval;
        _cretval = gdk_paintable_get_current_image(cast(GdkPaintable*)_cPtr);
        auto _retval = gobject.object.ObjectWrap._getDObject!(gdk.paintable.Paintable)(cast(GdkPaintable*)_cretval, Yes.Take);
        return _retval;
    }

    override void invalidateContents()
    {
        gdk_paintable_invalidate_contents(cast(GdkPaintable*)_cPtr);
    }
    
    override void invalidateSize()
    {
        gdk_paintable_invalidate_size(cast(GdkPaintable*)_cPtr);
    }

    ulong connectInvalidateContents(T)(T callback, Flag!"After" after = No.After)
        if (isCallable!T && is(ReturnType!T == void)
            && (Parameters!T.length < 1 || (ParameterStorageClassTuple!T[0] == ParameterStorageClass.none && is(Parameters!T[0] : gdk.paintable.Paintable)))
            && Parameters!T.length < 2)
    {
        extern(C) void _cmarshal(GClosure* _closure, GValue* _returnValue, uint _nParams, const(GValue)* _paramVals, void* _invocHint, void* _marshalData)
        {
            assert(_nParams == 1, "Unexpected number of signal parameters");
            auto _dClosure = cast(DGClosure!T*)_closure;
            Tuple!(Parameters!T) _paramTuple;

            static if (Parameters!T.length > 0)
                _paramTuple[0] = getVal!(Parameters!T[0])(&_paramVals[0]);

            _dClosure.cb(_paramTuple[]);
        }

        auto closure = new DClosure(callback, &_cmarshal);
        return connectSignalClosure("invalidate-contents", closure, after);
    }

    override PaintableFlags getFlags() { return PaintableFlags.Size; }
    override int getIntrinsicWidth() { return 100; }
    override int getIntrinsicHeight() { return 100; }
    override double getIntrinsicAspectRatio() { return 1.0; }

    override void snapshot(SnapshotGdk snapshot, double width, double height)
    {
        auto BLACK = new RGBA(0,0,0,1);
    
        if (time)
            time.destroy();
        if (timezone)
            time = DateTime.newNow(timezone);
        else
            time = DateTime.newNowLocal();

        auto snap = cast(SnapshotGtk) snapshot;

        snap.save();
    
        snap.translate(new Point(width / 2, height / 2));  
    
        import gsk.c.types: GskRoundedRect;
        auto initRect = new Rect();
        initRect = new Rect(initRect.init_(-50, -50, 100, 100)._cPtr(), No.Take);
        GskRoundedRect rr;
        RoundedRect outline = new RoundedRect(&rr, No.Take);
        outline = outline.initFromRect(initRect, 50);
        snap.appendBorder(outline, [4, 4, 4, 4], [BLACK, BLACK, BLACK, BLACK]);
    
        snap.save();
        snap.rotate(30 * time.getHour() + 0.5 * time.getMinute());
        initRect = new Rect(initRect.init_(-2, -23, 4, 25)._cPtr(), No.Take);
        outline = outline.initFromRect(initRect, 2);
        snap.pushRoundedClip(outline);
        snap.appendColor(BLACK, outline.bounds());
        snap.pop();
        snap.restore();
    
        snap.save();
        snap.rotate(6 * time.getMinute());
        initRect = new Rect(initRect.init_(-2, -43, 4, 45)._cPtr(), No.Take);
        outline = outline.initFromRect(initRect, 2);
        snap.pushRoundedClip(outline);
        snap.appendColor(BLACK, outline.bounds());
        snap.pop();
        snap.restore();
            
        snap.save();
        snap.rotate(6 * time.getSecond());
        initRect = new Rect(initRect.init_(-1, -44, 2, 45)._cPtr(), No.Take);
        outline = outline.initFromRect(initRect, 1);
        snap.pushRoundedClip(outline);
        snap.appendColor(new RGBA(1,0,0,1), outline.bounds());
        snap.pop();
        snap.restore();

        snap.restore();
    }
    

    static Clock[] ticking_clocks;
    static uint ticking_clock_id;

    /// 
    string location, time_format;

    ///
    DateTime time;

    /// 
    TimeZone timezone;

    /// 
    this(string location, TimeZone tz)
    {
	auto p = super(clockGetType());
	gpaintable = cast(GdkPaintable*) p._cPtr();
	setData("clock", cast(void*) this);

        this.location = location;
        
        timezone = tz ? tz : null;
        time = timezone ? DateTime.newNow(timezone) : DateTime.newNowLocal();
        time_format = time.format("%x\n%X");
        
        if ( !ticking_clock_id )
            ticking_clock_id = timeoutAddSeconds(0, 1, &clock_tick);

        ticking_clocks ~= this;

        // connectInvalidateContents( (Paintable paintable) {
        //     import core.memory : GC;
        //     GC.collect();
        // } );
    }

    ~this() {
        import glib.source;
        import std.algorithm : remove;

        ticking_clocks = ticking_clocks.remove!(el => el == this);

        if ( !ticking_clocks.length && ticking_clock_id != 0 )
            Source.remove(ticking_clock_id);
    }

    private bool clock_tick()
    {
        foreach (clock; ticking_clocks) {
            clock.setProperty!string ("time", clock.time.format("%x\n%X"));
            clock.invalidateContents();
        }
        
        return true;
    }
}
