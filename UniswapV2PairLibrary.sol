// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.4;

import '@prb/math/contracts/PRBMathUD60x18.sol';
import '@prb/math/contracts/PRBMathSD59x18.sol';
import '../interfaces/IERC20.sol';

// a library for performing various math operations

library UniswapV2PairLibrary {
    using PRBMathUD60x18 for uint256;
    using PRBMathSD59x18 for int256;

    uint256 private constant TIMESTAMP_20220821240000 = 1661126400; // 2022.8.21 24:00 timestamp
    uint256 private constant PERIOD_ONEWEEK = 604800; // Number of seconds for a week
    uint256 private constant PERIOD_ONEDAY = 86400; // Number of seconds for a day

    function getTrade1X(
        uint256 poolusdt,
        uint256 pooleth,
        uint256 _result
    ) public pure returns (uint256 x) {
        x = (poolusdt.mul(pooleth)).div(pooleth - _result.mul(10025e14)) - poolusdt;
    }

    function getTrade1P(
        uint256 poolusdt,
        uint256 pooleth,
        uint256 _resultFee
    ) public pure returns (uint256 p) {
        uint256 x1 = getTrade1X(poolusdt, pooleth, _resultFee);
        uint256 tradeUpool = poolusdt + x1;
        uint256 tradeEpool = pooleth - _resultFee;
        p = tradeUpool.div(tradeEpool);
    }

    //trexf都不需要了

    function getTrade1Trexf(
        uint256 _resultFee,
        uint256 _upool,
        uint256 _epool,
        uint256 _m3
    ) public pure returns (uint256 m3_trexf) {
        uint256 p = getTrade1P(_upool, _epool, _resultFee);
        m3_trexf = _resultFee.mul(25e14);
        m3_trexf = m3_trexf.div(2e18);
        m3_trexf = m3_trexf.mul(p.sqrt());
        m3_trexf = m3_trexf + _m3;
    }
   function getTrade1Treo(
        uint256 _resultFee,
        uint256 _upool,
        uint256 _epool,
        uint256 _lpA,
        uint256 _lpB,
        uint256 _m1,
        uint256 _pc
    ) public pure returns (uint256 m1_trade) {
        uint256 p = getTrade1P(_upool, _epool, _resultFee);
        m1_trade = _resultFee.mul(25e14);
        m1_trade = m1_trade.mul(p);
        m1_trade = m1_trade.mul(_lpB);
        m1_trade = m1_trade.div(_lpA + _lpB);
        m1_trade = m1_trade.div(_pc) + _m1;
    }

    function getTrade1Trex0(uint256 _resultFee,uint256 _balance0,uint256 _upool,uint256 _epool,uint256 _m2) public pure returns (uint256 m2_trex0){            
        uint256 x=getTrade1X(_upool,_epool,_resultFee);
        uint256 _tt1=_balance0-_upool-_m2.mul(1e19);
        uint256 tmp=_tt1-x;
        m2_trex0=tmp.div(1e18)+_m2;
    }

    function getTrade2Treo(uint256 _resultFee,uint256 _lpA,uint256 _lpB,uint256 _m1,uint256 _pc) public pure returns (uint256 m1_trade2){
        m1_trade2 = _resultFee.mul(25e14);
        m1_trade2 = m1_trade2.mul(_lpB);
        m1_trade2 = m1_trade2.div(_lpA + _lpB);
        m1_trade2 = m1_trade2.div(_pc) + _m1;
    }

    //function getTrade2Trexf(uint256 _resultFee,uint256 t1,uint256 _upool,uint256 _epool,uint256 _m3) public pure returns (uint256 m3_trexf_trade2){
        //uint256 p = getTrade2P(_upool,_epool,t1);
        //m3_trexf_trade2 = _resultFee.mul(25e14);
        //m3_trexf_trade2 = m3_trexf_trade2.div(2e18);
        //m3_trexf_trade2 = m3_trexf_trade2.div(p.sqrt());
        //m3_trexf_trade2 = m3_trexf_trade2 + _m3;
    //}
    function getTrade2P(uint256 poolusdt,uint256 pooleth,uint256 ethtrader) public pure returns (uint256 _p){
        //  lppool_trade=[n1-10*m2-x, n2+t[1] ] #Means USDT and ETH available for liquidity in the pool after trading/transaction
        // p=lppool_trade[0]/lppool_trade[1] #The price after the transaction
        uint256 _poolusdt = poolusdt - getTrade2X(poolusdt,pooleth,ethtrader);
        uint256 _pooleth = pooleth + ethtrader;
        _p = _poolusdt.div(_pooleth);
    }

    function getTrade2X(uint256 poolusdt,uint256 pooleth,uint256 ethtrader) public pure returns (uint256 _x){
        _x = poolusdt.mul(ethtrader).div(pooleth+ethtrader);
    }

    function getTrade2Trex0(uint256 _resultFee,uint256 balance1,uint256 _upool,uint256 _epool,uint256 _m2) public pure returns (uint256 m2_trex0_trade2){    
        uint256 t1 = balance1 - _epool;
        uint256 _x = getTrade2X(_upool,_epool,t1);
        uint256 _result = _resultFee.mul(10025e14);
        m2_trex0_trade2 = _x - _result;
        m2_trex0_trade2 = m2_trex0_trade2.div(1e18)+_m2;
    }

    // note: all parameters must contain 18 decimal places
    function bs(int256 S, int256 X, int256 duration, int256 sigma, int256 r) public pure returns(int256 fai) {
        int256 d1;
        int256 d2;
        {
            int256 d11 = (int256(S.div(X))).ln(); // ln(S/X)
            int256 d12 = r + ((sigma.pow(2e18)).abs()).div(2e18); // r+sigma(pow,2)/2 PRBMathSD59x18 must be used instead of PRBMathUD60x18, otherwise PRBMathUD60x18__LogInputTooSmall Error will be reported
            d12 = d12.mul(duration); // (r+sigma(pow,2)/2)*(T-t)
            int256 d13 = sigma.mul(duration.sqrt()); // sigma*((T-t).sqrt())
            d1 = (d11+d12).div(d13); // calculate d1
            d2 = d1 - d13; // calculate d2, could be negative
        }
        int256 c1 = S.mul(normsDist(d1)); // S*N(d1)
        int256 c21 = r.mul(duration); // r*(T-t)
        c21 = c21.exp(); // exp(r*(T-t))
        c21 = c21.inv(); // 1/exp(r*(T-t))    note: a^(-n)=1/(a^n)=(1/a)^n
        c21 = X.mul(c21); // X*(1/exp(r*(T-t)))
        int256 c2 = c21.mul(normsDist(d2)); // X*(1/exp(r*(T-t)))*N(d2)
        int256 y = c1 - c2;
        int256 c3 = c21.mul(normsDist(-d2));
        int256 c4 = S.mul(normsDist(-d1));
        int256 y1 = c3 - c4;
        fai = y+y1; // y+y1 must be positive
    }

    function normsDist(int256 x) public pure returns(int256 n){
        int256 b1 = 319381530000000000;
        int256 b2 = -356563782000000000;
        int256 b3 = 1781477937000000000;
        int256 b4 = -1821255978000000000;
        int256 b5 = 1330274429000000000;
        int256 p = 231641900000000000;
        int256 c = 398942280000000000;

        int256 one = 1e18;
        int256 x1 = x>=0?x:-x;
        int256 n1 = x1.pow(2e18);
        n1 = n1.div(2e18);
        n1 = n1.exp();
        n1 = n1.inv();
        n1 = c.mul(n1);
        if(x>=0){
            int256 t = one.div(one + p.mul(x));
            n1 = n1.mul(t);
            int256 n2 = t.mul(b5) + b4;
            n2 = t.mul(n2) + b3;
            n2 = t.mul(n2) + b2;
            n2 = t.mul(n2) + b1;

            n = (one - n1.mul(n2)).abs();
        } else {
            int256 t = one.div(one - p.mul(x));
            n1 = n1.mul(t);
            int256 n2 = t.mul(b5) + b4;
            n2 = t.mul(n2) + b3;
            n2 = t.mul(n2) + b2;
            n2 = t.mul(n2) + b1;

            n = (n1.mul(n2)).abs();
        }
    }

    // The parameters(except currentN) and the return value carry 18 decimal places
    function opMonth(int256 fai, uint256 currentN, int256[] memory assetPrices) public pure returns(int256 optPrice) {
        int256 intrValue;
        if(currentN<=4) {
            for (uint256 i = 0; i < currentN-1; i++) {
                intrValue+=(assetPrices[i+1]-assetPrices[i]).abs();
            }
            optPrice = (fai+intrValue).div(int256(currentN*1e18));
        } else {
            int256 intrValue1;
            int256 intr;
            int256 two = 2e18;
            int256 three = 3e18;
            uint256 f = currentN-1-(currentN-1)%4;
            for (uint256 i = 0; i < (currentN-1)%4; i++) {
                intrValue1+=(assetPrices[currentN-1-i]-assetPrices[currentN-2-i]).abs();
            }
            for (uint256 i = 0; i < f; i++) {
                intrValue+=(assetPrices[i+1]-assetPrices[i]).abs();
                if((i+1)%4==0){
                    intr+=intrValue.mul((two.div(three)).pow(int256(f/4-(i+1)/4+1)*1e18));
                    intrValue = 0;
                }
            }
        
            int256 denominator = (two.div(three)).pow(int256(f/4)*1e18);
            denominator = 1e18-denominator;
            denominator = denominator.mul(8e18);
            denominator+=1e18;
            denominator+=int256((currentN-1)%4)*1e18;

            optPrice = (fai+intrValue1+intr).div(denominator);
        }
    }

    function convertTo18Decimal(uint256 value, uint8 decimal) public pure returns(uint256 valueWith18Decimal) {
        if(decimal==18){
            valueWith18Decimal = value;
        } else if(decimal<18){
            valueWith18Decimal = value * (10**(18-decimal));
        } else {
            valueWith18Decimal = value / (10**(decimal-18));
        }
    }

    function convertFrom18Decimal(uint256 valueWith18Decimal, uint8 decimal) public pure returns(uint256 value) {
        if(decimal==18){
            value = valueWith18Decimal;
        } else if(decimal<18){
            value = valueWith18Decimal / (10**(18-decimal));
        } else {
            value = valueWith18Decimal * (10**(decimal-18));
        }
    }
     // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');

        amountOut = cal(reserveIn, reserveOut, amountIn);
    }

    function cal(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amountIn
    ) private pure returns (uint256 amountOut) {
        uint256 halfAmountIn = amountIn.div(2e18);
        uint256 k = (halfAmountIn).div(halfAmountIn+reserveIn);
        uint256 product = 1e18;
        for (uint256 i = 1; i <= 25; i++) {
            uint256 pow = 1e18;
            for (uint256 j = 1; j <= i; j++) {
                pow = pow.mul(2e18);
            }
            product = product.mul(1e18-k.div(pow));
        }
        uint256 _amountOut = reserveOut.mul(1e18-product);

        uint256 k_ = halfAmountIn.div(amountIn+reserveIn);
        uint256 product_ = 1e18;
        for (uint256 i = 1; i <= 21; i++) {
            uint256 pow_ = 1e18;
            for (uint256 j = 1; j <= i; j++) {
                pow_ = pow_.mul(2e18);
            }
            product_ = product_.mul(1e18-k_.div(pow_));
        }
        uint256 _amountOut_ = (reserveOut-_amountOut).mul(1e18-product_);

        amountOut = (_amountOut+_amountOut_).mul(10000e18).div(10025e18);
    }  

}




