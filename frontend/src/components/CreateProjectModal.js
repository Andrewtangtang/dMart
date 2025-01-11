import React, { useState } from 'react';
import web3Service from '../services/web3Service';
import { ethers } from 'ethers';

const CreateProjectModal = ({ isOpen, onClose }) => {
  const [formData, setFormData] = useState({
    title: '',
    descriptionCID: '',
    imageCID: '',
    targetAmount: '100',
    duration: '1'
  });
  const [transactionLoading, setTransactionLoading] = useState(false);

  const handleBackgroundClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    try {
      setTransactionLoading(true);
      
      // 1. 確保錢包已連接
      if (!web3Service.isConnected()) {
        console.log('Connecting wallet...');
        await web3Service.connectWallet();
      }
      
      // 2. 檢查網路
      const isCorrectNetwork = await web3Service.checkNetwork();
      console.log('Network check:', isCorrectNetwork ? 'correct' : 'incorrect');
      
      if (!isCorrectNetwork) {
        alert('請將 MetaMask 切換到 Sepolia 測試網');
        return;
      }

      // 3. 準備合約所需的參數
      const targetAmount = parseInt(formData.targetAmount);
      const depositAmount = Math.floor(targetAmount * 0.3);
      const durationInSeconds = parseInt(formData.duration) * 30 * 24 * 60 * 60;

      // 模擬的合約地址（這裡需要替換成實際的合約地址）
      const contractAddress = "0x0000000000000000000000000000000000000000";

      // 驗證合約地址格式
      if (!ethers.utils.isAddress(contractAddress)) {
        console.log('Invalid contract address:', contractAddress);
        throw new Error('無效的合約地址');
      }

      // 4. 準備交易資料
      const tx = {
        to: ethers.utils.getAddress(contractAddress),
        value: ethers.utils.parseEther("0"),
        gasLimit: 21000
      };

      console.log('Project data:', {
        title: formData.title,
        description: formData.descriptionCID,
        image: formData.imageCID,
        targetAmount: `${targetAmount} USDT`,
        deposit: `${depositAmount} USDT`,
        duration: `${formData.duration} month(s)`,
        contractAddress: tx.to
      });

      console.log('Starting transaction');

      // 5. 發送交易
      const signer = web3Service.signer;
      await signer.sendTransaction(tx);

      console.log('Transaction sent');
      
    } catch (error) {
      console.log('Transaction failed:', {
        code: error.code,
        message: error.message
      });
      
      // 只有在不是用戶取消交易的情況下才顯示錯誤訊息
      if (error.code !== 4001) {
        alert('交易失敗: ' + error.message);
      }
    } finally {
      setTransactionLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onClick={handleBackgroundClick}>
      <div className="bg-white rounded-lg p-8 max-w-3xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">發起募資專案</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* 專案標題 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              專案標題
            </label>
            <input
              type="text"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
              required
            />
          </div>

          {/* 專案介紹 CID */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              專案介紹 CID
            </label>
            <input
              type="text"
              value={formData.descriptionCID}
              onChange={(e) => setFormData({ ...formData, descriptionCID: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
              placeholder="請輸入 IPFS 專案介紹 CID"
              required
            />
          </div>

          {/* 圖片 CID */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              圖片 CID
            </label>
            <input
              type="text"
              value={formData.imageCID}
              onChange={(e) => setFormData({ ...formData, imageCID: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
              placeholder="請輸入 IPFS 圖片 CID"
              required
            />
          </div>

          {/* 募資金額 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              募資金額
            </label>
            <select
              value={formData.targetAmount}
              onChange={(e) => setFormData({ ...formData, targetAmount: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F] mb-2"
            >
              <option value="100">100 USDT</option>
              <option value="200">200 USDT</option>
              <option value="300">300 USDT</option>
            </select>
            <p className="text-sm text-gray-600">
              需支付保證金：{(Number(formData.targetAmount) * 0.3).toFixed(2)} USDT（募資金額的30%）
            </p>
          </div>

          {/* 募資期限 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              募資期限
            </label>
            <select
              value={formData.duration}
              onChange={(e) => setFormData({ ...formData, duration: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
            >
              <option value="1">1 個月</option>
              <option value="3">3 個月</option>
              <option value="6">6 個月</option>
            </select>
          </div>

          {/* 按鈕組 */}
          <div className="flex gap-4 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-6 py-3 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
              disabled={transactionLoading}
            >
              取消
            </button>
            <button
              type="submit"
              disabled={transactionLoading}
              className="flex-1 px-6 py-3 bg-[#FFAD36] text-white rounded-md hover:bg-[#FF9D16] transition-colors disabled:bg-gray-300 disabled:cursor-not-allowed"
            >
              {transactionLoading ? '處理中...' : '確認發起'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CreateProjectModal; 