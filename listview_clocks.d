module listview_clocks;

import std.logger;
import std.typecons : Yes;
import std.algorithm : min;

import gobject.types, gobject.object, gobject.value, gobject.closure, gobject.cclosure;
import gio.types : ApplicationFlags;
import gio.simple_action, gio.application : ApplicationGio = Application;
import gio.list_store, gio.list_model;
import glib.time_zone, glib.date_time, glib.variant, glib.global;
import gtk.types, gtk.widget, gtk.application, gtk.application_window, gtk.scrolled_window, gtk.box, gtk.label, 
       gtk.picture, gtk.list_item, gtk.signal_list_item_factory, gtk.no_selection, gtk.grid_view, gtk.snapshot, 
       gtk.expression, gtk.constant_expression, gtk.property_expression, gtk.closure_expression;
import gdk.paintable, gdk.rgba;
import gsk.rounded_rect;
import graphene.point, graphene.rect;


class GtkClock : ObjectWrap
{
    mixin(objectMixin);
    
    static GtkClock[] ticking_clocks;
    static uint ticking_clock_id;

    /* Name of the location we're displaying time for */
    string location;
    ///
    DateTime time;
    /* We allow this to be null for the local timezone */
    TimeZone timezone;

    ListStore store;
    Paintable paintable;
    string time_format;
    gtk.snapshot.Snapshot snap;

    this(string location, TimeZone tz, ListStore store)
    {
        super(GTypeEnum.Object);

        this.location = location;
        if (tz)
            timezone = new TimeZone(tz.copy_());
        else
            timezone = null;
        
        this.store = store;
        
        snap = new gtk.snapshot.Snapshot();
        paintable = paint();
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
            clock.paintable = clock.paint();
            clock.time_format = clock.time.format("%x\n%X");
        }
        /* schedules a redraw */
        store.itemsChanged(0,0,0);
        return true;
    }

    private Paintable paint()
    {
        snap = new gtk.snapshot.Snapshot();
        do_snapshot();
        return snap.toPaintable();
    }

    private void do_snapshot()
    {
        double width = 100;
        double height = 100;
        auto BLACK = new RGBA(new RGBA(0,0,0,1).copy_());

        if (time)
            time.destroy();
        if (timezone)
            time = new DateTime(DateTime.newNow(timezone).copy_());
        else
            time = new DateTime(DateTime.newNowLocal().copy_());
       
        snap.save();

        snap.translate(new Point(width / 2, height / 2));

        import gsk.c.functions, gsk.c.types;
        import graphene.c.functions, graphene.c.types;

        GdkRGBA blackc = GdkRGBA(0,0,0,1);
        auto black = new RGBA(&blackc);

        auto gpt = graphene_point_t(-50, -50);
        auto gst = graphene_size_t(100, 100);
        auto initRectc = graphene_rect_t(gpt, gst);
        GskRoundedRect outlinec;
        auto initRect = new Rect(&initRectc);
        RoundedRect outline = new RoundedRect(&outlinec).initFromRect(initRect, 50);
        snap.appendBorder(outline, [4, 4, 4, 4], [black, black, black, black]);

        snap.save();
        snap.rotate(30 * time.getHour() + 0.5 * time.getMinute());
        gpt = graphene_point_t(-2, -23);
        gst = graphene_size_t(4, 25);
        initRectc = graphene_rect_t(gpt, gst);
        // initRectc = graphene_rect_t(graphene_point_t(-2, -23), graphene_size_t(4, 25));  <== crashes too ! (instead of the 3 preceding lines)
        gsk_rounded_rect_init_from_rect(&outlinec, &initRectc, 2);
        outline = new RoundedRect(&outlinec);
        snap.pushRoundedClip(outline);
        snap.appendColor(black, outline.bounds());
        snap.pop();
        snap.restore();

        snap.save();
        snap.rotate(6 * time.getMinute());
        gpt = graphene_point_t(-2, -43);
        gst = graphene_size_t(4, 45);
        initRectc = graphene_rect_t(gpt, gst);
        gsk_rounded_rect_init_from_rect(&outlinec, &initRectc, 2);
        outline = new RoundedRect(&outlinec);
        snap.pushRoundedClip(outline);
        snap.appendColor(black, outline.bounds());
        snap.pop();
        snap.restore();

        snap.save();
        snap.rotate(6 * time.getSecond());
        gpt = graphene_point_t(-1, -44);
        gst = graphene_size_t(2, 45);
        initRectc = graphene_rect_t(gpt, gst);
        gsk_rounded_rect_init_from_rect(&outlinec, &initRectc, 1);
        outline = new RoundedRect(&outlinec, No.Take);
        snap.pushRoundedClip(outline);
        GdkRGBA redc = GdkRGBA(1,0,0,1);
        auto red = new RGBA(&redc);
        snap.appendColor(red, outline.bounds());
        snap.pop();
        snap.restore();

        snap.restore();
    }
}

class ClockWindow : ApplicationWindow
{   
    this(Application app)
    {
        super(app);
        setTitle("Gtk4 Clocks & Lists");
        setDefaultSize(600, 400);

        auto sw = new ScrolledWindow();
        sw.setPolicy(PolicyType.Automatic, PolicyType.Automatic);
        setChild(sw);

        auto factory = new SignalListItemFactory();
        factory.connectSetup( &onFactorySetup );
        factory.connectBind(&onFactoryBind);

        auto selModel = new NoSelection(create_clocks_model());
        auto gridview = new GridView(selModel, factory);
        with (gridview) {
            hscrollPolicy(ScrollablePolicy.Natural);
            vscrollPolicy(ScrollablePolicy.Natural);
            marginStart(5);
            marginTop(5);
            marginEnd(5);
            marginBottom(5);
            updateProperty([AccessibleProperty.Label], [new Value("Clocks")]);
        }
        sw.setChild(gridview);

      /* Stress the app so it crashes earlier */
        auto mdl = cast(ListStore) selModel.getModel();
        mdl.connectItemsChanged( (uint p, uint a, uint r, ListModel _) {
            import core.memory : GC;
            GC.collect();
        }, Yes.After );
    }

    void onFactorySetup(ObjectWrap obj, SignalListItemFactory _)
    {
        auto list_item = cast(ListItem) obj;
        auto box = new Box(Orientation.Vertical, 0);
        box.append(new Label());        // location Label
        box.append(new Picture());      
        box.append(new Label());        // time Label
        list_item.setChild(box);
    }

    void onFactoryBind(ObjectWrap obj, SignalListItemFactory _)
    {
        auto list_item = cast(ListItem) obj;
        auto box = cast(Box) list_item.getChild();
        auto clock = cast(GtkClock) list_item.getItem();
        
        auto loc = cast(Label) box.getFirstChild();
        loc.setText(clock.location);

        auto pic = cast(Picture) loc.getNextSibling();
        pic.setPaintable(clock.paintable);

        auto lbl = cast(Label) pic.getNextSibling();
        lbl.setText(clock.time_format);
    }

    final ListStore create_clocks_model()
    {
        auto store = new ListStore(GTypeEnum.Object);

        /* local time */
        auto clock = new GtkClock("local", null, store);
        store.append(clock);
        
        /* UTC time */
        clock = new GtkClock("UTC", TimeZone.newUtc(), store); 
        store.append(clock);
        
        /* A bunch of timezones from everywhere */
        clock = new GtkClock("San Francisco", TimeZone.newIdentifier("America/Los_Angeles"), store);
        store.append(clock);

        clock = new GtkClock("Xalapa", TimeZone.newIdentifier("America/Mexico_City"), store);
        store.append(clock);

        clock = new GtkClock("Boston", TimeZone.newIdentifier("America/New_York"), store);
        store.append(clock);

        clock = new GtkClock("London", TimeZone.newIdentifier("Europe/London"), store);
        store.append(clock);

        clock = new GtkClock("Berlin", TimeZone.newIdentifier("Europe/Berlin"), store);
        store.append(clock);

        clock = new GtkClock("Moscow", TimeZone.newIdentifier("Europe/Moscow"), store);
        store.append(clock);

        /* There is an expected half hour offset here ... in few other places too */
        clock = new GtkClock("New Delhi", TimeZone.newIdentifier("Asia/Kolkata"), store);
        store.append(clock);

        clock = new GtkClock("Shanghai", TimeZone.newIdentifier("Asia/Shanghai"), store);
        store.append(clock);

        return store;
    }
}

class ClockApp : Application
{
    ClockWindow mainWin;
    
    this()
    {
        super("clocksGtk4.d", ApplicationFlags.DefaultFlags);

        debug {
            globalLogLevel(LogLevel.trace);
        } else {
            globalLogLevel(LogLevel.warning);
        }

        connectStartup(&onStartup);
        connectActivate(&onActivate);
    }

    void onStartup(ApplicationGio app)
    {
        auto quitAction = new SimpleAction("quit", null);
        quitAction.connectActivate(&onQuit);
        addAction(quitAction);
    }

    void onActivate(ApplicationGio app)
    {
        if (!mainWin) {
            mainWin = new ClockWindow(this);
            addWindow(mainWin);
        }
        mainWin.present();
    }

    void onQuit(Variant parameter, SimpleAction action) { quit(); }
}

int main(string[] args)
{
    import std.file : thisExePath;
    string path = thisExePath();

    return new ClockApp().run(args);
}

