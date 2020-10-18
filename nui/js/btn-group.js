// Component for a button group, handles scrolling and such
Vue.component('neo-btn-group', {
    template: '#btn_group_template',
    mixins: [winMsgMixin],
    inject: ['menu'],

    props: {
        buttons: { type: Array, required: true },
        length: { type: Number, default: 10 },
    },

    methods: {
        handleAction({ action }) {
            if (action === 'up') this.index = this.addToIndex(-1);
            else if (action === 'down') this.index = this.addToIndex(1);
        },
        addToIndex(val) {
            let index = this.index;
            index += val;

            // this will wrap the menu past index bounds
            if (index >= this.buttons.length) index = 0;
            else if (index < 0) index = this.buttons.length - 1;

            return index;
        },
        getTopFromIndex(index) {
            const length = this.length;
            let top = this.top || 0;

            if (index < top) top = index;
            else if (index >= top + length) top = index - length + 1;

            return top;
        },
    },
    computed: {
        index: {
            get() {
                return this.menu.index || 0;
            },
            set(v) {
                this.$set(this.menu, 'index', v);
            },
        },
        top: {
            get() {
                return this.menu._top || 0;
            },
            set(v) {
                this.$set(this.menu, '_top', v);
            }
        },
        displayButtons() {
            // filter out buttons to display
            return (
                this.buttons
                    // map used to include their true index for render
                    .map((btn, i) => ({ btn, current: i === this.index }))
                    .filter(
                        (_, i) => i >= this.top && i < this.top + this.length,
                    )
            );
        },
    },
    watch: {
        index(index) {
            // this will move the top according to the index
            this.top = this.getTopFromIndex(index);

            // send a move event
            const btn = this.buttons[this.index];
            postClient({
                type: 'move',
                button: btn.id,
                menu: this.menu.id,
                index
            });
        },
    },
});
