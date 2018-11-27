//
//  TimestampExtraction.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/23/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

public class TimestampExtraction: BasicOperation {
    public init() {
        super.init(fragmentFunctionName:"timestampExtractionFragment", numberOfInputs:1)
    }
}
