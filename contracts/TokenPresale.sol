pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/WhitelistedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import './Token.sol';

/*
  Contract handling token presale. Basicaly combination of openzeppelin contacts.
  Two additional features are that it returns eth for the last investor if sent too much
  and checks private presale token cap.
*/
contract TokenPresale is MintedCrowdsale, FinalizableCrowdsale, WhitelistedCrowdsale {
    using SafeMath for uint256;

    // presale token cap
    uint256 public cap;

    // parameter for saving last presale investor overflow while it is returned
    uint256 public overflowWei;

    constructor(
        Token _token,
        address _wallet,
        uint256 _rate,
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _cap
    )
    public
        Crowdsale(_rate, _wallet, _token)
        TimedCrowdsale(_openingTime, _closingTime) {

        require(_cap > 0);
        cap = _cap;
    }

    /*
      OpenZeppelin override for pre purchase validation - checks if token cap not reached
    */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
      super._preValidatePurchase(_beneficiary, _weiAmount);
      require(cap > token.totalSupply());
    }

    /*
      OpenZeppelin override for pre purchase processing - in addition to standard routine
      overflow for last presale investor is returned if there are less tokens than eth sent
    */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
      uint256 _currentSupply = token.totalSupply();
      if (_currentSupply.add(_tokenAmount) > cap) {
        _tokenAmount = cap.sub(_currentSupply);
      }
      super._processPurchase(_beneficiary, _tokenAmount);
      uint256 _weiAmount = _tokenAmount.div(rate);

      require(_weiAmount <= msg.value);
      uint256 _weiToReturn = msg.value.sub(_weiAmount);
      weiRaised = weiRaised.sub(_weiToReturn);
      overflowWei = _weiToReturn;
      _beneficiary.transfer(_weiToReturn);
    }

    /*
      OpenZeppelin override for pre funds forwarding - forwards funds without overflow
    */
    function _forwardFunds() internal {
      wallet.transfer(msg.value.sub(overflowWei));
      overflowWei = 0;
    }

    /*
      OpenZeppelin override for finalization routine - transfers token ownership to wallet
    */
    function finalization() internal {
      Token _token = Token(token);
      _token.transferOwnership(wallet);
    }

    /**
      OpenZeppelin override - checks whether cap has been reached or other conditions met
    */
    function hasClosed() public view returns (bool) {
      Token _token = Token(token);
      bool _soldOut = _token.totalSupply() >= cap;
      return super.hasClosed() || _soldOut;
    }
}
