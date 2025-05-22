module listview_clocks;

import std.logger;
import std.typecons : Yes;
import std.algorithm : min;

import gobject.types, gobject.object, gobject.value;
import gio.types : ApplicationFlags;
import gio.simple_action, gio.application : ApplicationGio = Application;
import gio.list_store, gio.list_model;
import glib.time_zone, glib.date_time, glib.variant, glib.global;
import gtk.types, gtk.widget, gtk.application, gtk.application_window, gtk.scrolled_window, gtk.box, gtk.label, 
       gtk.picture, gtk.list_item, gtk.signal_list_item_factory, gtk.no_selection, gtk.grid_view;
import gdk.paintable, gdk.rgba;
import gsk.rounded_rect;
import graphene.point, graphene.rect;

import clocks;


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
    }

private:

    void onFactorySetup(ObjectWrap obj, SignalListItemFactory _)
    {
        auto list_item = cast(ListItem) obj;
        auto box = new Box(Orientation.Vertical, 0);
        box.append(new Label());        // location Label
        box.append(new Picture());
        auto time_label = new Label();
        box.append(time_label);
        list_item.setChild(box);

        Expression expression = ConstantExpression.newForValue(new Value(list_item));
        auto clock_expression = new PropertyExpression(ListItem._getGType(), expression, "item");
        expression = new PropertyExpression(Clock._getGType(), clock_expression, "time");
        // Must add a ref
        expression._cPtr(Yes.Dup);
        auto watch = expression.bind(time_label, "label", time_label);
    }

    void onFactoryBind(ObjectWrap obj, SignalListItemFactory _)
    {
        auto list_item = cast(ListItem) obj;
        auto box = cast(Box) list_item.getChild();
        auto clock = cast(Clock) list_item.getItem();
        
        auto loc = cast(Label) box.getFirstChild();
        loc.setText(clock.location);

        auto pic = cast(Picture) loc.getNextSibling();
        pic.setPaintable(clock);

        // auto lbl = cast(Label) pic.getNextSibling();
        // lbl.setText(clock.getProperty!string ("time"));
    }

    ListStore create_clocks_model()
    {
        auto store = new ListStore(GTypeEnum.Object);

        /* local time */
        store.append(new Clock("local", null));
        
        /* UTC time */
        store.append(new Clock("UTC", TimeZone.newUtc()));
        
        /* A bunch of timezones from everywhere */
        store.append(new Clock("San Francisco", TimeZone.newIdentifier("America/Los_Angeles")));

        store.append(new Clock("Xalapa", TimeZone.newIdentifier("America/Mexico_City")));

        store.append(new Clock("Boston", TimeZone.newIdentifier("America/New_York")));

        store.append(new Clock("London", TimeZone.newIdentifier("Europe/London")));

        store.append(new Clock("Berlin", TimeZone.newIdentifier("Europe/Berlin")));

        store.append(new Clock("Moscow", TimeZone.newIdentifier("Europe/Moscow")));

        /* There is an expected half hour offset here ... in few other places too */
        store.append(new Clock("New Delhi", TimeZone.newIdentifier("Asia/Kolkata")));

        store.append(new Clock("Shanghai", TimeZone.newIdentifier("Asia/Shanghai")));

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

    private void onStartup(ApplicationGio app)
    {
        auto quitAction = new SimpleAction("quit", null);
        quitAction.connectActivate( (Variant pmr, SimpleAction act) => quit() );
        addAction(quitAction);
    }

    private void onActivate(ApplicationGio app)
    {
        if (!mainWin) {
            mainWin = new ClockWindow(this);
            addWindow(mainWin);
        }
        mainWin.present();
    }
}

int main(string[] args)
{
    return new ClockApp().run(args);
}
