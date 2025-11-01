import { EventEmitter } from "events";

/**
 * /server/match.ts
 * Basic TypeScript template for a matching engine module.
 *
 * - Defines types for orders and matches
 * - Provides a simple MatchingEngine class with lifecycle methods
 * - Includes placeholders for persistence/validation/matching logic
 */


/* ----- Types ----- */

export type Side = "buy" | "sell";

export interface Order {
    id: string;
    side: Side;
    price: number;
    quantity: number;
    timestamp?: number;
    // add metadata as needed
}

export interface Match {
    buyOrderId: string;
    sellOrderId: string;
    price: number;
    quantity: number;
    timestamp: number;
}

export interface MatchResult {
    matches: Match[];
    remaining?: Order | null;
}

/* ----- Utilities (placeholders) ----- */

function now(): number {
    return Date.now();
}

function validateOrder(order: Order): void {
    if (!order.id) throw new Error("order.id required");
    if (!["buy", "sell"].includes(order.side)) throw new Error("invalid side");
    if (!(order.price > 0)) throw new Error("price must be > 0");
    if (!(order.quantity > 0)) throw new Error("quantity must be > 0");
}


export function matchOrders(incoming: Order, book: Order[]): MatchResult {
    const matches: Match[] = [];
    let remainingQty = incoming.quantity;

    // naive FIFO scanning
    for (const bookOrder of book) {
        if (remainingQty <= 0) break;
        const priceAcceptable =
            incoming.side === "buy" ? incoming.price >= bookOrder.price : incoming.price <= bookOrder.price;

        if (!priceAcceptable) continue;

        const qty = Math.min(remainingQty, bookOrder.quantity);
        matches.push({
            buyOrderId: incoming.side === "buy" ? incoming.id : bookOrder.id,
            sellOrderId: incoming.side === "sell" ? incoming.id : bookOrder.id,
            price: bookOrder.price,
            quantity: qty,
            timestamp: now(),
        });

        remainingQty -= qty;
    }

    const remaining: Order | null =
        remainingQty > 0 ? { ...incoming, quantity: remainingQty, timestamp: incoming.timestamp ?? now() } : null;

    return { matches, remaining };
}


export class MatchingEngine extends EventEmitter {
    private buyBook: Order[] = [];
    private sellBook: Order[] = [];
    private running = false;

    constructor() {
        super();
    }

    start() {
        if (this.running) return;
        this.running = true;
        // start background tasks if necessary
        this.emit("started");
    }

    stop() {
        if (!this.running) return;
        this.running = false;
        this.emit("stopped");
    }

    /**
     * Submit an order to the engine. Returns matches produced immediately.
     */
    submitOrder(order: Order): Match[] {
        order.timestamp = order.timestamp ?? now();
        validateOrder(order);

        const oppositeBook = order.side === "buy" ? this.sellBook : this.buyBook;
        const sameBook = order.side === "buy" ? this.buyBook : this.sellBook;

        const { matches, remaining } = matchOrders(order, oppositeBook);

        // TODO: apply fills to oppositeBook orders (reduce/remove) in a real implementation

        if (remaining) {
            // add remaining to own side book
            sameBook.push(remaining);
        }

        if (matches.length > 0) {
            this.emit("matched", matches);
        } else {
            this.emit("queued", order);
        }

        return matches;
    }

    getOrderBookSnapshot() {
        return {
            buy: [...this.buyBook],
            sell: [...this.sellBook],
        };
    }

    clear() {
        this.buyBook = [];
        this.sellBook = [];
        this.emit("cleared");
    }
}

/* ----- Export a default instance (optional) ----- */

export const defaultEngine = new MatchingEngine();
export default MatchingEngine;