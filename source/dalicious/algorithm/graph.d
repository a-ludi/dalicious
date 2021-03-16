/**
    This module contains graph algorithms.

    Copyright: © 2021 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.algorithm.graph;

import dalicious.container : RingBuffer;
import std.range;
import std.traits;


struct HopcroftKarpImpl(node_t, nodes_u_it, nodes_v_it, adjacency_t, count_t = size_t)
    if (
        isIntegral!node_t && isUnsigned!node_t &&
        isForwardRange!nodes_u_it && is(ElementType!nodes_u_it == node_t) &&
        isForwardRange!nodes_v_it && is(ElementType!nodes_v_it == node_t) &&
        isRandomAccessRange!adjacency_t && isForwardRange!(ElementType!adjacency_t) &&
        is(ElementType!(ElementType!adjacency_t) == node_t) &&
        isIntegral!count_t && isUnsigned!count_t
    )
{
    struct nil_t { }
    enum NIL = nil_t();
    enum inf = count_t.max;

    private
    {
        nodes_u_it U;
        nodes_v_it V;
        adjacency_t Adj;
        node_t[node_t] Pair_U;
        node_t[node_t] Pair_V;
        count_t[node_t] _Dist;
        count_t _DistNIL;
        RingBuffer!node_t Q;
    }


    this(nodes_u_it U, nodes_v_it V, adjacency_t adjacency)
    {
        this.U = U;
        this.V = V;
        this.Adj = adjacency;
        // TODO allow user to pass a reusable buffer (node_t[])
        this.Q = RingBuffer!node_t(adjacency.length);
    }


    count_t opCall()
    {
        count_t matching;

        while (BFS())
            foreach (const node_t u; U)
            {
                if (u !in Pair_U)
                    if (DFS(u))
                        ++matching;
            }

        return matching;
    }

private:

    bool BFS()
    {
        foreach (const node_t u; U)
        {
            if (u !in Pair_U)
            {
                Dist(u, 0u);
                Q.pushBack(u);
            }
            else
            {
                Dist(u, inf);
            }
        }

        Dist(NIL, inf);

        while (!Q.empty)
        {
            const auto u = Q.front;
            Q.popFront();

            if (Dist(u) < Dist(NIL))
                foreach (const node_t v; Adj[u])
                {
                    if (Dist(Pair_V, v) == inf)
                    {
                        Dist(Pair_V, v) = Dist(u) + 1;
                        if (v in Pair_V)
                            Q.pushBack(Pair_V[v]);
                    }
                }
        }

        return Dist(NIL) < inf;
    }


    bool DFS(const node_t u)
    {
        foreach (const node_t v; Adj[u])
        {
            if (Dist(Pair_V, v) == Dist(u) + 1)
            {
                if(v !in Pair_V || DFS(Pair_V[v]))
                {
                    Pair_V[v] = u;
                    Pair_U[u] = v;

                    return true;
                }
            }
        }

        Dist(u) = inf;

        return false;
    }


    ref count_t Dist(node_t n)
    {
        return _Dist[n];
    }


    void Dist(node_t n, count_t c)
    {
        _Dist[n] = c;
    }


    ref count_t Dist(nil_t)
    {
        return _DistNIL;
    }


    void Dist(nil_t, count_t c)
    {
        _DistNIL = c;
    }


    ref count_t Dist(ref node_t[node_t] Pair, node_t n)
    {
        if (n in Pair)
            return Dist(Pair[n]);
        else
            return Dist(NIL);
    }
}

// test typing
unittest
{
    uint[][] adjacency;
    uint[] U;
    uint[] V;
    cast(void) HopcroftKarpImpl!(
        uint,
        typeof(U),
        typeof(V),
        typeof(adjacency),
    )(U, V, adjacency);
}

// test typing
unittest
{
    import std.algorithm;

    auto adjacency = iota(0u).map!(i => iota(0u));
    auto U = repeat(0u).take(0u);
    auto V = repeat(0u).take(0u);
    cast(void) HopcroftKarpImpl!(
        uint,
        typeof(U),
        typeof(V),
        typeof(adjacency),
    )(U, V, adjacency);
}



/// Takes as input a bipartite graph and produces as output a maximum
/// cardinality matching – a set of as many edges as possible with the
/// property that no two edges share an endpoint.
///
/// Calling this function with a non-bipartite graph results in undefined
/// behaviour.
count_t hopcroftKarp(
    count_t = size_t,
    nodes_u_it,
    nodes_v_it,
    adjacency_t,
)(nodes_u_it U, nodes_v_it V, adjacency_t adjacency)
    if (
        isForwardRange!nodes_u_it && isForwardRange!nodes_v_it &&
        is(ElementType!nodes_u_it == ElementType!nodes_v_it) &&
        isIntegral!(ElementType!nodes_u_it) && isUnsigned!(ElementType!nodes_u_it) &&
        isRandomAccessRange!adjacency_t && isForwardRange!(ElementType!adjacency_t) &&
        is(ElementType!(ElementType!adjacency_t) == ElementType!nodes_u_it) &&
        isIntegral!count_t && isUnsigned!count_t
    )
{
    alias node_t = ElementType!nodes_u_it;
    auto impl = HopcroftKarpImpl!(
        node_t,
        nodes_u_it,
        nodes_v_it,
        adjacency_t,
        count_t,
    )(U, V, adjacency);

    return impl();
}

/// Example
unittest
{
    //            ____
    //           /    \.
    // 0   1   2 | 3   4
    // |  / \ /| | |\  |
    // | /   X | / | \ |
    // |/   / \|/  |  \|
    // 5   6   7   8   9
    //
    uint[][] adjacency;
    adjacency.length = 10;

    alias connect = (from, uint[] neighbors...) {
        adjacency[from] ~= neighbors;
    };

    connect(0u,  5u);
    connect(1u,  5u, 7u);
    connect(2u,  6u, 7u);
    connect(3u,  8u, 9u);
    connect(4u,  7u, 9u);
    connect(5u,  0u, 1u);
    connect(6u,  2u);
    connect(7u,  2u, 4u);
    connect(8u,  3u);
    connect(9u,  3u, 4u);

    auto count = hopcroftKarp(iota(5u), iota(5u, 10u), adjacency);

    assert(count == 5);
}
