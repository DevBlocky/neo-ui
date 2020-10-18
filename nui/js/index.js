// function used to POST messages to the Lua client
async function postClient(payload, route = 'message') {
    let url = new URL(route, `https://${GetParentResourceName()}`);

    let req = await fetch(url.toString(), {
        method: 'POST',
        body: JSON.stringify(payload),
    });

    console.assert(req.status === 200);
    let txt = await req.json();
    console.assert(txt === 'OK');
}

// sanitizes text for html then puts it inside a template
function safeTextWithTemplate(texts, template) {
    if (!(texts instanceof Array)) texts = [texts];

    texts.forEach((text, i) => {
        const escapedText = text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');

        template = template.replace(`{${i}}`, escapedText);
    });
    return template;
}

// this is a generic mixin for adding event handling to components
const winMsgMixin = {
    created() {
        this.addListener();
    },
    activated() {
        this.addListener();
    },
    beforeDestroy() {
        this.removeListener();
    },
    deactivated() {
        this.removeListener();
    },

    methods: {
        addListener() {
            window.removeEventListener('message', this.onEvent);
            window.addEventListener('message', this.onEvent);
        },
        removeListener() {
            window.removeEventListener('message', this.onEvent);
        },
        onEvent({ data }) {
            const events = {
                action: 'handleAction',
                menu_create: 'handleCreate',
                button_create: 'handleCreate',
                menu_update: 'handleUpdate',
                button_update: 'handleUpdate',
                menu_destroy: 'handleDestroy',
                button_destroy: 'handleDestroy',
            };
            let handlerName = events[data.type];
            if (!handlerName || !this[handlerName]) return;
            this[handlerName](data);
        },
    },
};

(() => {
    // this is for testing before lua bindings
    let app = new Vue({
        mixins: [winMsgMixin],
        el: '#app',
        data: {
            // a list of all buttons
            buttons: [],
            // a list of all menus
            menus: [],
        },
        methods: {
            // adds menus and buttons
            handleCreate({ type, payload }) {
                (type === 'menu_create' ? this.menus : this.buttons).push(
                    payload,
                );
            },
            // updates the values of a menu or button
            handleUpdate({ type, payload }) {
                // find the object to update
                let arr = type === 'menu_update' ? this.menus : this.buttons;
                let obj = arr.find((x) => payload.id === x.id);
                if (!obj) return;

                // set the new obj properties
                // this.$set needed for reactivity
                for (const k in payload) this.$set(obj, k, payload[k]);
            },
            handleDestroy({ type, payload }) {
                let arr = type === 'menu_destroy' ? this.menus : this.buttons;
                let obj = arr.find(x => x.id == payload.id);
                if (!obj) return;

                arr.splice(arr.indexOf(obj));
                console.log(this.menus, this.buttons);
            },
        },
        computed: {
            openMenus() {
                const openMenus = this.menus.filter((x) => x.open);
                return openMenus;
            },
            menuButtons() {
                let mBtns = {};
                for (let m of this.menus)
                    mBtns[m.id] = this.buttons.filter((btn) =>
                        m.buttons.includes(btn.id),
                    );

                return mBtns;
            },
        },
        watch: {
            // sends menu open/close events to client
            openMenus(current, old) {
                // this happens when opening the same menu
                if (current.length === old.length) return;

                // detect newly opened menus
                let openedMenus = current.filter((x) => old.indexOf(x) < 0);
                for (let om of openedMenus)
                    postClient({ type: 'open', menu: om.id });

                // detect newly closed menus
                let closedMenus = old.filter((x) => current.indexOf(x) < 0);
                for (let cm of closedMenus)
                    postClient({ type: 'close', menu: cm.id });
            },
        },
    });

    // send a ready event when the lua client is ready
    // if the lua client is ready before this listener is added, then this will essentially do nothing
    window.addEventListener('message', ({ data: { type } }) => {
        if (type !== 'ready') return;
        postClient({ type: 'ready' });
    });
    // this is here in case the lua client is ready before the ui
    // if the lua client is not ready, then this won't do anything on that side
    postClient({ type: 'ready' });
})();
