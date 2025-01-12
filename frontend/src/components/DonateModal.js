import React, { useState, useEffect } from 'react';
import { ethers,Contract } from 'ethers';
import web3Service from '../services/web3Service';
import ProjectAbi from "../data/ProjectAbi.json";

// TODO: 這個函數將來要改為實際從智能合約獲取回饋內容
const getBenefits = async (contractAddress) => {
  
  console.log(`從合約 ${contractAddress} 獲取方案的回饋內容`);
  
  // 模擬的回饋內容資料
  return {
    basic: [
      '專案完成後的產品一份',
      '專屬贊助者感謝卡',
      '提前體驗權限'
    ],
    advanced: [
      '專案完成後的產品一份',
      '專屬贊助者感謝卡',
      '提前體驗權限',
      '限量精美週邊商品',
      '專屬社群討論區權限'
    ]
  };
};

const DonateModal = ({ isOpen, onClose, projectTitle, contractAddress }) => {
  const [selectedPlan, setSelectedPlan] = useState(null);
  const [benefits, setBenefits] = useState(null);
  const [loading, setLoading] = useState(true);
  const [transactionLoading, setTransactionLoading] = useState(false);

  const handleBackgroundClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  useEffect(() => {
    const loadBenefits = async () => {
      if (isOpen && contractAddress) {
        try {
          const result = await getBenefits(contractAddress);
          setBenefits(result);
        } catch (error) {
          console.error('獲取回饋內容失敗:', error);
        } finally {
          setLoading(false);
        }
      }
    };

    loadBenefits();
  }, [isOpen, contractAddress]);

  if (!isOpen) return null;
  if (loading) return <div>載入中...</div>;

  const plans = [
    {
      id: 1,
      price: 20,
      currency: 'USDT',
      title: '基本贊助方案',
      planType: 'basic',
      benefits: benefits?.basic || [],
      estimatedDelivery: '2024 年 6 月'
    },
    {
      id: 2,
      price: 40,
      currency: 'USDT',
      title: '進階贊助方案',
      planType: 'advanced',
      benefits: benefits?.advanced || [],
      estimatedDelivery: '2024 年 6 月'
    }
  ];

  const handleConfirm = async () => {
    if (!selectedPlan) return;
    
    try {
      setTransactionLoading(true);
      
      console.log('選擇的方案:', selectedPlan);
      console.log('目標合約地址:', contractAddress);
      
      // 確保錢包已連接
      if (!web3Service.isConnected()) {
        console.log('錢包未連接，嘗試連接...');
        await web3Service.connectWallet();
      }
      
      // 檢查網路
      const isCorrectNetwork = await web3Service.checkNetwork();
      console.log('網路檢查結果:', isCorrectNetwork);
      
      if (!isCorrectNetwork) {
        alert('請將 MetaMask 切換到 Sepolia 測試網');
        return;
      }

      // 確保合約地址是有效的以太坊地址
      if (!ethers.utils.isAddress(contractAddress)) {
        console.log('無效的合約地址:', contractAddress);
        throw new Error('無效的合約地址');
      }

      // 發送交易（這只會觸發 MetaMask 確認視窗）
      const signer = web3Service.signer;
      const contract = new Contract(contractAddress, ProjectAbi, signer);
      const donationAmount = selectedPlan.price;
      const tx = await contract.donate(donationAmount);
      console.log('交易已發送:', tx.hash);

      // 等待交易完成
      const receipt = await tx.wait();
      console.log('交易完成:', receipt);
        
      // 關閉模態框
      onClose();
      
    } catch (error) {
      console.error('交易失敗的詳細資訊:', error);
      if (error.code === 4001) {
        alert('您取消了交易');
      } else {
        alert('交易失敗: ' + error.message);
      }
    } finally {
      setTransactionLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onClick={handleBackgroundClick}>
      <div className="bg-white rounded-lg p-8 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="text-center mb-8">
          <h2 className="text-2xl font-bold text-gray-900">贊助專案</h2>
          <p className="text-gray-600 mt-2">{projectTitle}</p>
        </div>

        {/* 方案選擇 */}
        <div className="grid gap-4 mb-8">
          {plans.map((plan) => (
            <div
              key={plan.id}
              className={`border-2 rounded-lg p-6 cursor-pointer transition-all
                ${selectedPlan?.id === plan.id 
                  ? 'border-[#00AA9F] bg-[#00AA9F]/5' 
                  : 'border-gray-200 hover:border-[#00AA9F]/50'}`}
              onClick={() => setSelectedPlan(plan)}
            >
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-lg font-medium text-gray-900">{plan.title}</h3>
                  <p className="text-2xl font-bold text-[#00AA9F] mt-1">
                    {plan.price} {plan.currency}
                  </p>
                </div>
                <div className="h-6 w-6 rounded-full border-2 flex items-center justify-center
                  ${selectedPlan?.id === plan.id ? 'border-[#00AA9F]' : 'border-gray-300'}">
                  {selectedPlan?.id === plan.id && (
                    <div className="h-3 w-3 rounded-full bg-[#00AA9F]" />
                  )}
                </div>
              </div>
              
              <div className="space-y-2">
                {plan.benefits.map((benefit, index) => (
                  <div key={index} className="flex items-start gap-2">
                    <svg className="w-5 h-5 text-[#00AA9F] mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-gray-600">{benefit}</span>
                  </div>
                ))}
              </div>

              <div className="mt-4 pt-4 border-t border-gray-100">
                <p className="text-sm text-gray-500">
                  預計出貨時間：{plan.estimatedDelivery}
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* 按鈕組 */}
        <div className="flex gap-4">
          <button
            onClick={onClose}
            className="flex-1 px-6 py-3 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
          >
            取消
          </button>
          <button
            onClick={handleConfirm}
            disabled={!selectedPlan}
            className={`flex-1 px-6 py-3 rounded-md text-white transition-colors
              ${selectedPlan 
                ? 'bg-[#FFAD36] hover:bg-[#FF9D16]' 
                : 'bg-gray-300 cursor-not-allowed'}`}
          >
            確認贊助
          </button>
        </div>

        {/* 關閉按鈕 */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-600"
        >
          <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
  );
};

export default DonateModal; 