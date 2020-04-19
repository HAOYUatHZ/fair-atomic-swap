# On the optionality and fairness of Atomic Swaps

This is the repo for the paper [On the optionality and fairness of Atomic Swaps](https://dl.acm.org/doi/10.1145/3318041.3355460) (published at [The First ACM Conference on Advances in Financial Technologies (AFT’19)](http://aft.acm.org)) by [Runchao Han](https://github.com/SebastianElvis), [Haoyu Lin](https://github.com/HAOYUatHZ) and [Jiangshan Yu](http://jiangshanyu.com).

## Directory

- `/data`: relevant experimental data
- `/doc`: relevant documentations
- `/paper`: source code of the paper
- `/src`: source code
  - `/src/atomicswap`: the Go code for launching Atomic Swaps with BTC and ETH
  - `/src/crawler`: a simple crawler for getting exchange rate data
  - `/src/evaluation`: code for evaluating the unfairness of Atomic Swaps, including the volatility analysis and the Cox-Ross-Rubinstein model
- `/test`: testing code for connecting BTC nodes

## Standardisation

We submitted our protocol to Ethereum as an EIP proposal, which is assigned with the ID [EIP-2266](https://eips.ethereum.org/EIPS/eip-2266) and currently under review.

## Reference

Runchao Han, Haoyu Lin and Jiangshan Yu. On the optionality and fairness of Atomic Swaps. The First ACM Conference on Advances in Financial Technologies (AFT’19), Oct 2019.

## Contacts

Please feel free to contact any of the authors ([Runchao Han](mailto:runchao.han@monash.edu), [Haoyu Lin](mailto:chris.haoyul@gmail.com) and [Jiangshan Yu](mailto:jiangshan.yu@monash.edu)) for any issues about this project or collaboration.

## License

This code is licensed under GNU GPLv3.
