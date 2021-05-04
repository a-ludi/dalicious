/**
    This module contains graph algorithms.

    Copyright: © 2021 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.algorithm.graph;

import dalicious.math : NaturalNumberSet;
import dalicious.container : RingBuffer;
import std.algorithm;
import std.functional;
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


/**
    Calculate connected components of the graph defined by `hasEdge`.

    Params:
        hasEdge = Binary predicate taking two nodes of type `size_t` which is
                  true iff the first node is adjacent to the second node.
        n =       Number of nodes in the graph. `hasEdge` must be defined for
                  every pair of integer in `0 .. n`.
    Returns: Array of components represented as arrays of node indices.
*/
size_t[][] connectedComponents(alias hasEdge)(size_t n)
{
    alias _hasEdge = binaryFun!hasEdge;

    auto unvisitedNodes = NaturalNumberSet(n, Yes.addAll);
    auto nodesBuffer = new size_t[n];
    auto components = appender!(size_t[][]);

    while (!unvisitedNodes.empty)
    {
        // discover startNode's component by depth-first search
        auto component = discoverComponent!_hasEdge(unvisitedNodes);
        // copy component indices to buffer
        auto restNodesBuffer = component
            .elements
            .copy(nodesBuffer);
        // append component to result
        components ~= nodesBuffer[0 .. $ - restNodesBuffer.length];
        // reduce node buffer
        nodesBuffer = restNodesBuffer;

    }

    return components.data;
}

///
unittest
{
    import std.algorithm :
        equal,
        min;

    //    _____________
    //   /             \
    // (0) --- (1) --- (2)     (3) --- (4)
    enum n = 5;
    alias connect = (u, v, x, y) => (u == x && v == y) || (u == y && v == x);
    alias hasEdge = (u, v) => connect(u, v, 0, 1) ||
                              connect(u, v, 1, 2) ||
                              connect(u, v, 2, 0) ||
                              connect(u, v, 3, 4);

    auto components = connectedComponents!hasEdge(n);

    assert(equal(components, [
        [0, 1, 2],
        [3, 4],
    ]));
}

///
unittest
{
    import std.algorithm :
        equal,
        min;

    //    _____________
    //   /             \
    // (0) --- (1) --- (2)     (3) --- (4)
    //   \_____________________/
    enum n = 5;
    alias connect = (u, v, x, y) => (u == x && v == y) || (u == y && v == x);
    alias hasEdge = (u, v) => connect(u, v, 0, 1) ||
                              connect(u, v, 1, 2) ||
                              connect(u, v, 2, 0) ||
                              connect(u, v, 0, 3) ||
                              connect(u, v, 3, 4);

    auto components = connectedComponents!hasEdge(n);

    import std.stdio;
    assert(equal(components, [
        [0, 1, 2, 3, 4],
    ]));
}


private NaturalNumberSet discoverComponent(alias hasEdge)(ref NaturalNumberSet nodes)
{
    assert(!nodes.empty, "cannot discoverComponent of an empty graph");

    // prepare component
    auto component = NaturalNumberSet(nodes.maxElement);
    // select start node
    auto currentNode = nodes.minElement;

    discoverComponent!hasEdge(nodes, currentNode, component);

    return component;
}


private void discoverComponent(alias hasEdge)(ref NaturalNumberSet nodes, size_t currentNode, ref NaturalNumberSet component)
{
    // move currentNode from available nodes to the component
    component.add(currentNode);
    nodes.remove(currentNode);

    // try to find successor of current node
    foreach (nextNode; nodes.elements)
    {
        if (hasEdge(currentNode, nextNode))
        {
            assert(
                hasEdge(nextNode, currentNode),
                "connectedComponents may be called only on an undirected graph",
            );
            // found successor -> recurse

            discoverComponent!hasEdge(nodes, nextNode, component);
        }
    }
}


///
struct SingleSourceShortestPathsSolution(weight_t) if (isNumeric!weight_t)
{
    static if (isFloatingPoint!weight_t)
        enum unconnectedWeight = weight_t.infinity;
    else
        enum unconnectedWeight = weight_t.max;
    enum noPredecessor = size_t.max;

    ///
    size_t startNode;

    ///
    size_t[] topologicalOrder;
    private weight_t[] _distance;
    private size_t[] _predecessor;


    ///
    @property size_t numNodes() const pure nothrow @safe
    {
        return topologicalOrder.length;
    }


    private size_t originalNode(size_t u) const pure nothrow @safe
    {
        return topologicalOrder[u];
    }


    ///
    @property const(weight_t)[] distances() const pure nothrow @safe
    {
        return _distance[];
    }


    ///
    @property ref weight_t distance(size_t u) pure nothrow @safe
    {
        return _distance[u];
    }


    ///
    @property weight_t distance(size_t u) const pure nothrow @safe
    {
        return _distance[u];
    }


    ///
    @property bool isConnected(size_t u) const pure nothrow @safe
    {
        return distance(u) < unconnectedWeight;
    }


    ///
    @property ref size_t predecessor(size_t u) pure nothrow @safe
    {
        return _predecessor[u];
    }


    ///
    @property size_t predecessor(size_t u) const pure nothrow @safe
    {
        return _predecessor[u];
    }


    ///
    @property bool hasPredecessor(size_t u) const pure nothrow @safe
    {
        return predecessor(u) != noPredecessor;
    }


    ///
    static struct ReverseShortestPath
    {
        private const(SingleSourceShortestPathsSolution!weight_t)* _solution;
        private size_t _to;
        private size_t _current;


        private this(const(SingleSourceShortestPathsSolution!weight_t)* solution, size_t to)
        {
            this._solution = solution;
            this._to = to;
            this._current = solution !is null && solution.isConnected(to)
                ? to
                : noPredecessor;
        }


        @property const(SingleSourceShortestPathsSolution!weight_t) solution() pure nothrow @safe
        {
            return *_solution;
        }


        ///
        @property size_t from() const pure nothrow @safe
        {
            return _solution.startNode;
        }


        ///
        @property size_t to() const pure nothrow @safe
        {
            return _to;
        }


        ///
        @property bool empty() const pure nothrow @safe
        {
            return _current == noPredecessor;
        }


        ///
        @property size_t front() const pure nothrow @safe
        {
            assert(
                !empty,
                "Attempting to fetch the front of an empty SingleSourceShortestPathsSolution.ReverseShortestPath",
            );

            return _current;
        }


        ///
        void popFront() pure nothrow @safe
        {
            assert(!empty, "Attempting to popFront an empty SingleSourceShortestPathsSolution.ReverseShortestPath");

            this._current = _solution !is null
                ? solution.predecessor(_current)
                : noPredecessor;
        }


        ///
        @property ReverseShortestPath save() const pure nothrow @safe @nogc
        {
            typeof(return) copy;
            copy._solution = this._solution;
            copy._to = this._to;
            copy._current = this._current;

            return copy;
        }
    }


    /// Traverse shortest path from dest to startNode; empty if `!isConnected(dest)`.
    ReverseShortestPath reverseShortestPath(size_t dest) const pure nothrow
    {
        return ReverseShortestPath(&this, dest);
    }
}


/**
    Calculate all shortest paths in DAG starting at `start`. The
    functions `hasEdge` and `weight` define the graphs structure and
    weights, respectively. Nodes are represented as `size_t` integers.
    The graph must be directed and acyclic (DAG).

    Params:
        hasEdge = Binary predicate taking two nodes of type `size_t` which is
                  true iff the first node is adjacent to the second node.
        weight =  Binary function taking two nodes of type `size_t` which
                  returns the weight of the edge between the first and the
                  second node. The function may be undefined if `hasEdge`
                  returns false for the given arguments.
        n =       Number of nodes in the graph. `hasEdge` must be defined for
                  every pair of integer in `0 .. n`.
    Throws: NoDAG if a cycle is detected.
    Returns: SingleSourceShortestPathsSolution
*/
auto dagSingleSourceShortestPaths(alias hasEdge, alias weight)(size_t start, size_t n)
{
    import std.experimental.checkedint;

    alias _hasEdge = binaryFun!hasEdge;
    alias _weight = binaryFun!weight;
    alias weight_t = typeof(_weight(size_t.init, size_t.init));
    alias saturated = Checked!(weight_t, Saturate);

    SingleSourceShortestPathsSolution!weight_t result;

    with (result)
    {
        // sort topological
        topologicalOrder = topologicalSort!_hasEdge(n);
        alias N = (u) => originalNode(u);

        _distance = uninitializedArray!(weight_t[])(n);
        _distance[] = result.unconnectedWeight;
        _distance[start] = 0;
        _predecessor = uninitializedArray!(size_t[])(n);
        _predecessor[] = size_t.max;

        foreach (u; topologicalOrder.countUntil(start) .. n)
            foreach (v; u + 1 .. n)
                if (_hasEdge(N(u), N(v)))
                {
                    auto vDistance = saturated(distance(N(v)));
                    auto uDistance = saturated(distance(N(u))) + saturated(_weight(N(u), N(v)));

                    if (vDistance > uDistance)
                    {
                        distance(N(v)) = uDistance.get();
                        predecessor(N(v)) = N(u);
                    }
                }
    }

    return result;
}

///
unittest
{
    import std.algorithm : equal;

    //    _____________   _____________
    //   /             v /             v
    // (0) --> (1) --> (2)     (3) --> (4)
    enum n = 5;
    alias hasEdge = (u, v) => (u + 1 == v && u != 2) ||
                              (u + 2 == v && u % 2 == 0);
    alias weight = (u, v) => 1;

    auto shortestPaths = dagSingleSourceShortestPaths!(hasEdge, weight)(0, n);

    assert(equal(shortestPaths.reverseShortestPath(4), [4, 2, 0]));
    assert(shortestPaths.distance(4) == 2);
    assert(equal(shortestPaths.reverseShortestPath(2), [2, 0]));
    assert(shortestPaths.distance(2) == 1);
    assert(equal(shortestPaths.reverseShortestPath(1), [1, 0]));
    assert(shortestPaths.distance(1) == 1);
    assert(equal(shortestPaths.reverseShortestPath(3), size_t[].init));
    assert(!shortestPaths.isConnected(3));
}


/**
    Sort nodes of a DAG topologically. The graph structure is defined by
    `hasEdge` and `n`. Nodes are represented as `size_t` integers. The graph
    must be directed and acyclic (DAG).

    Params:
        hasEdge = Binary predicate taking two nodes of type `size_t` which is
                  true iff the first node is adjacent to the second node.
        n =       Number of nodes in the graph. `hasEdge` must be defined for
                  every pair of integer in `0 .. n`.
    Throws: NoDAG if a cycle is detected.
    Returns: SingleSourceShortestPathsSolution
*/
auto topologicalSort(alias hasEdge)(size_t n)
{
    alias _hasEdge = binaryFun!hasEdge;

    // list that will contain the sorted nodes
    auto sortedNodes = new size_t[n];

    auto sortedNodesHead = sortedNodes[];
    void enqueueNode(size_t node)
    {
        sortedNodesHead[$ - 1] = node;
        --sortedNodesHead.length;
    }

    // keep track which nodes have been visited
    auto unvisitedNodes = NaturalNumberSet(n, Yes.addAll);
    auto temporaryVisitedNodes = NaturalNumberSet(n);

    void visit(size_t node)
    {
        if (node !in unvisitedNodes)
            // already visited
            return;

        if (node in temporaryVisitedNodes)
            // cycle detected
            throw new NoDAG();

        temporaryVisitedNodes.add(node);

        foreach (nextNode; unvisitedNodes.elements)
            if (_hasEdge(node, nextNode))
                visit(nextNode);

        temporaryVisitedNodes.remove(node);
        unvisitedNodes.remove(node);
        enqueueNode(node);
    }

    foreach (node; unvisitedNodes.elements)
        visit(node);

    return sortedNodes;
}

///
unittest
{
    import std.algorithm : equal;

    //    _____________   _____________
    //   /             v /             v
    // (0) --> (1) --> (2)     (3) --> (4)
    enum n = 5;
    alias hasEdge = (u, v) => (u + 1 == v && u != 2) ||
                              (u + 2 == v && u % 2 == 0);

    auto topologicalOrder = topologicalSort!hasEdge(n);

    assert(equal(topologicalOrder, [3, 0, 1, 2, 4]));
}

///
unittest
{
    import std.exception : assertThrown;

    //    _____________   _____________
    //   /             v /             v
    // (0) --> (1) --> (2)     (3) --> (4)
    //   ^_____________________________/
    enum n = 5;
    alias hasEdge = (u, v) => (u + 1 == v && u != 2) ||
                              (u + 2 == v && u % 2 == 0) ||
                              u == 4 && v == 0;

    assertThrown!NoDAG(topologicalSort!hasEdge(n));
}


/// Thrown if a cycle was detected.
class NoDAG : Exception
{
    this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super("not a DAG: graph has cycles", file, line, next);
    }
}

