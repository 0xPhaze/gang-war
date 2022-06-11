import numpy as np
import matplotlib.pyplot as plt
from eth_abi import encode_single
import argparse


def main(args):
    prob = gang_war_won_prob(
        args.attack_force, args.defense_force, args.baron_defense
    )
    enc = encode_single('uint256', int(prob * 10**18))
    print("0x" + enc.hex())


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--attack_force", type=int)
    parser.add_argument("--defense_force", type=int)
    parser.add_argument("--baron_defense", type=int)
    return parser.parse_args()


def gang_war_won_prob(a, b, baronDefense):
    C_D = 2
    C_A = 0.65
    C_B = 50
    C_LIM = 150

    a += 1
    b += 1

    s = (1 - (1 - a / C_LIM) ** 2) * (a < C_LIM) + (a >= C_LIM)

    b = ((1 - s) * C_D + s * C_A) * b + C_B * baronDefense

    p = a / (a + b)
    p = (p > 0.5) * (1 - 4 * (1 - p) ** 3) + (p <= 0.5) * 4 * (p ** 3)
    return p


def plot():

    # plot_x_lim = 150
    plot_x_lim = 1024
    x = np.arange(plot_x_lim)

    X, Y = np.meshgrid(x, x)
    Z = gang_war_won_prob(X, Y)

    plt.style.use('default')
    plt.rcParams.update({'font.size': 22})

    plt.figure(figsize=(12, 12))
    plt.xlabel('Attackers')
    plt.xlabel(r'Attackers ($F_{attackers}$)')
    plt.ylabel(r'Defenders ($F_{defenders}$)')
    plt.xlim(1, x[-1])
    plt.ylim(x[-1], 1)
    plt.gca().xaxis.tick_top()
    plt.gca().xaxis.set_label_position('top')
    plt.gca().xaxis.labelpad = 20

    cs = plt.contourf(X, Y, Z, np.linspace(0, 1, 50), cmap='coolwarm')
    levels = [0.1, 0.25, 0.5, 0.75, 0.9]
    cs2 = plt.contour(cs, levels=levels, cmap='seismic')
    cbar = plt.colorbar(cs, ticks=levels)
    cbar.add_lines(cs2)
    cbar.ax.set_ylabel('Attacker injury rate ($P$)')
    cbar.ax.yaxis.labelpad = 20
    cbar.ax.set_yticklabels([f'{l:.0%}' for l in levels])

    plt.plot([0, plot_x_lim], [0, plot_x_lim], 'k')
    plt.clim([0, 1])


if __name__ == '__main__':
    args = parse_args()
    main(args)
