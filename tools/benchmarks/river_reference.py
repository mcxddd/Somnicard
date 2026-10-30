"""Independent sequence-form LP certificate for exported finite river games.

This tests the implementation inside its abstraction, not real-game exploitability.
Requires scipy (installed only in the local evaluation venv).
"""
from pathlib import Path
import json
import numpy as np
from scipy import sparse
from scipy.optimize import linprog

ROOT = Path(__file__).resolve().parents[2]

def verify(case):
    nodes, terms = case['nodes'], case['terminals']
    types = int(case['buckets'])
    sequences, equations, realizations = [], [], []
    for player in range(2):
        ids, rows, reach = {}, [{0: 1.0}], [1.0]
        def visit(node_id, own, parent):
            if node_id < 0:
                return
            node = nodes[node_id]
            if node['player'] != player:
                for child in node['children']:
                    visit(child, own, parent)
                return
            row = {parent: -1.0}
            for action, child in enumerate(node['children']):
                seq = len(reach)
                ids[node_id, own, action] = seq
                row[seq] = 1.0
                reach.append(reach[parent] * case['average'][node_id * types + own][action])
                visit(child, own, seq)
            rows.append(row)
        for own in range(types):
            visit(0, own, 0)
        rr, cc, vv = [], [], []
        for i, row in enumerate(rows):
            for j, value in row.items():
                rr.append(i); cc.append(j); vv.append(value)
        equations.append(sparse.csr_matrix((vv, (rr, cc)), shape=(len(rows), len(reach))))
        sequences.append(ids)
        realizations.append(np.array(reach))
    payoff = {}
    for a in range(types):
        for b in range(types):
            chance = case['joint'][a][b]
            if not chance:
                continue
            def terminal_walk(node_id, s0, s1):
                if node_id < 0:
                    term = terms[-node_id - 1]
                    key = s0, s1
                    payoff[key] = payoff.get(key, 0) + chance * (term['m'] * case['outcomes'][a][b] + term['c'])
                    return
                node = nodes[node_id]
                for action, child in enumerate(node['children']):
                    if node['player'] == 0:
                        terminal_walk(child, sequences[0][node_id, a, action], s1)
                    else:
                        terminal_walk(child, s0, sequences[1][node_id, b, action])
            terminal_walk(0, 0, 0)
    keys = list(payoff)
    matrix = sparse.csr_matrix(([payoff[k] for k in keys], ([k[0] for k in keys], [k[1] for k in keys])), shape=(len(realizations[0]), len(realizations[1])))
    rhs = [np.r_[1.0, np.zeros(e.shape[0]-1)] for e in equations]
    for p in range(2):
        assert np.max(np.abs(equations[p] @ realizations[p] - rhs[p])) < 1e-8
    br0 = linprog(-(matrix @ realizations[1]), A_eq=equations[0], b_eq=rhs[0], bounds=(0, None), method='highs')
    br1 = linprog(matrix.T @ realizations[0], A_eq=equations[1], b_eq=rhs[1], bounds=(0, None), method='highs')
    assert br0.success and br1.success
    epsilon = (-br0.fun - br1.fun) / 2
    assert abs(epsilon - case['epsilon']) < 1e-6, (epsilon, case['epsilon'])
    # Independent equilibrium LP: max e1^T v, E1^T v <= A^T x, E0 x=e0.
    nx, nv = matrix.shape[0], equations[1].shape[0]
    equilibrium = linprog(np.r_[np.zeros(nx), -rhs[1]],
        A_ub=sparse.hstack([-matrix.T, equations[1].T]), b_ub=np.zeros(matrix.shape[1]),
        A_eq=sparse.hstack([equations[0], sparse.csr_matrix((equations[0].shape[0], nv))]), b_eq=rhs[0],
        bounds=[(0, None)]*nx + [(None, None)]*nv, method='highs')
    assert equilibrium.success, equilibrium.message
    cfr_value = float(realizations[0] @ matrix @ realizations[1])
    return {"scenario": case['scenario'], "detail": case['detail'], "buckets": types,
        "public_nodes": len(nodes), "sequence_variables": list(matrix.shape),
        "lp_value": -equilibrium.fun, "cfr_value": cfr_value,
        "value_difference": abs(-equilibrium.fun-cfr_value), "lp_best_response_epsilon": epsilon,
        "reported_epsilon": case['epsilon'], "certificate_error": abs(epsilon-case['epsilon']),
        "converged": case['result'].get('converged', False), "duration_ms": case['duration_ms'], "max_step_us": case['max_step_us']}

if __name__ == '__main__':
    cases = json.loads((ROOT/'.local/river-reference-111.json').read_text(encoding='utf-8'))
    report = {"method": "Independent sequence-form LP via scipy HiGHS, within the exported abstraction only", "cases": [verify(case) for case in cases]}
    target = ROOT/'docs/benchmarks/river-reference-1.11.0.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))
