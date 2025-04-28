module clocks;

import std.logger;
import std.string : toStringz;

import gobject.types, gobject.object, gobject.value;
import gio.list_store, gio.list_model;
import glib.time_zone, glib.date_time, glib.global;
import gtk.types, gtk.snapshot : SnapshotGtk = Snapshot;
import gdk.types, gdk.paintable, gdk.rgba, gdk.snapshot : SnapshotGdk = Snapshot;
import gsk.rounded_rect;
import graphene.point, graphene.rect;

import gobject.c.types, gobject.c.functions;
import gdk.c.types, gdk.c.functions;

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
		super(cast(ObjectC*) cObj, take);
		gpaintable = cast(GdkPaintable*) cObj;
	}

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
					ObjectC.sizeof,                             /* instance size */
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
				g_type_add_interface_static(clockType, Paintable.getGType(), &itfPaintInfo);
			}

			return clockType;
		}

        static void clockClassInit(GTypeClass* klass)
		{
			GObjectClass* objectClass;

			parentClass = cast(GObjectClass*) g_type_class_peek_parent(klass);
			objectClass = cast(GObjectClass*) klass;

			objectClass.finalize = &clockFinalize;
		}

		static void clockFinalize(ObjectC* object)
		{

			/* must chain up - finalize parent */
			parentClass.finalize(object);
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
            auto clock = getDObject!Clock (paintable);
            auto snapshot_ = getDObject!SnapshotGdk (snapshot);

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
        gdk_paintable_compute_concrete_size(cast(GdkPaintable*)cPtr, specifiedWidth, specifiedHeight, defaultWidth, defaultHeight, cast(double*)&concreteWidth, cast(double*)&concreteHeight);
    }
    
    override gdk.paintable.Paintable getCurrentImage()
    {
        GdkPaintable* _cretval;
        _cretval = gdk_paintable_get_current_image(cast(GdkPaintable*)cPtr);
        auto _retval = gobject.object.ObjectWrap.getDObject!(gdk.paintable.Paintable)(cast(GdkPaintable*)_cretval, Yes.Take);
        return _retval;
    }

    override void invalidateContents()
    {
        gdk_paintable_invalidate_contents(cast(GdkPaintable*)cPtr);
    }
    
    override void invalidateSize()
    {
        gdk_paintable_invalidate_size(cast(GdkPaintable*)cPtr);
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
        initRect = new Rect(initRect.init_(-50, -50, 100, 100).copy_());
        GskRoundedRect rr;
        RoundedRect outline = new RoundedRect(&rr);
        outline = outline.initFromRect(initRect, 50);
        snap.appendBorder(outline, [4, 4, 4, 4], [BLACK, BLACK, BLACK, BLACK]);
    
        snap.save();
        snap.rotate(30 * time.getHour() + 0.5 * time.getMinute());
        initRect = new Rect(initRect.init_(-2, -23, 4, 25).copy_());
        outline = outline.initFromRect(initRect, 2);
        snap.pushRoundedClip(outline);
        snap.appendColor(BLACK, outline.bounds());
        snap.pop();
        snap.restore();
    
        snap.save();
        snap.rotate(6 * time.getMinute());
        initRect = new Rect(initRect.init_(-2, -43, 4, 45).copy_());
        outline = outline.initFromRect(initRect, 2);
        snap.pushRoundedClip(outline);
        snap.appendColor(BLACK, outline.bounds());
        snap.pop();
        snap.restore();
            
        snap.save();
        snap.rotate(6 * time.getSecond());
        initRect = new Rect(initRect.init_(-1, -44, 2, 45).copy_());
        outline = outline.initFromRect(initRect, 1);
        snap.pushRoundedClip(outline);
        snap.appendColor(new RGBA(1,0,0,1), outline.bounds());
        snap.pop();
        snap.restore();

        snap.restore();
    }
    

    static Clock[] ticking_clocks;
    static uint ticking_clock_id;

    string location, time_format;

    ///
    DateTime time;

    /// 
    TimeZone timezone;

    /// 
	this(string location, TimeZone tz, ListStore store = null)
	{
		auto p = super(clockGetType());
		gpaintable = cast(GdkPaintable*) p.cPtr();
		setData("clock", cast(void*) this);
        
        this.location = location;
        
        timezone = tz ? tz : null;
        time = timezone ? DateTime.newNow(timezone) : DateTime.newNowLocal();
        time_format = time.format("%x\n%X");
        
        if ( !ticking_clock_id )
            ticking_clock_id = timeoutAddSeconds(0, 1, &clock_tick);

        ticking_clocks ~= this;
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
            // TODO implement properties to update the labels
            // g_object_notify_by_pspec (G_OBJECT (clock), properties[PROP_TIME]);
            // clock.time_format = clock.time.format("%x\n%X");
            clock.invalidateContents();
        }
        /* Stress the app so it crashes earlier */
        import core.memory : GC;
        infof("collecting : %s", "...");
        GC.collect();
        return true;
    }

}
